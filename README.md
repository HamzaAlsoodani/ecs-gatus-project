# Gatus Health Monitoring on AWS ECS Fargate

> A production-grade health monitoring platform deployed on AWS using Terraform, Docker, and GitHub Actions — built from the ground up with security and automation as first principles.

![Architecture](images/architecture.gif)

---

## Live Demo

![Gatus Dashboard](images/demo.gif)

| Endpoint | URL |
|----------|-----|
| Monitoring Dashboard | https://tm.hamza-alsoodani.com |
| Main Website | https://hamza-alsoodani.com |

---

## What is Gatus?

[Gatus](https://github.com/TwiN/gatus) is an open-source health monitoring tool that tracks the availability and performance of endpoints in real time. It provides a clean, self-hosted status page with support for HTTP, DNS, ICMP, and TCP checks — without the overhead of a large monitoring stack.

In this project, Gatus monitors the live infrastructure itself: both domains, SSL certificate expiry, DNS resolution, and AWS ECR availability.

---

## Architecture

![Architecture Diagram](images/architecture.png)

```
User
 │
 ▼
Route53 (DNS)  ──────────────────────────────────────┐
 │                                                    │
 ▼                                                ACM Certificate
Application Load Balancer (public subnets)           │
 │         ←───────────────────────────────────────── ┘
 ▼
ECS Fargate Task (private subnets)  ←── ECR (container image)
 │
 ▼
NAT Gateway (outbound only)
 │
 ▼
Internet (ECR pulls, health checks)
```

Traffic enters through Route53, hits the ALB in the public subnets, and is forwarded to the Gatus container running in the private subnets. The container never has a public IP — all outbound traffic exits through a NAT Gateway.

---

## Key Design Decisions

### Private ECS workloads
ECS tasks run in private subnets with no public IP assigned. The ALB is the single entry point, meaning the container is never directly reachable from the internet. This follows AWS security best practices and reduces the attack surface significantly.

### Custom multistage Dockerfile
Rather than using the official Gatus image, I wrote a custom multistage Dockerfile from scratch:

- **Stage 1 (builder):** Uses `golang:1.26-alpine` to compile the Go source into a single static binary
- **Stage 2 (runtime):** Uses `scratch` — an entirely empty base image containing only the compiled binary and config

This reduces the final image size by over 95% compared to a standard Go build image and removes all unnecessary tooling from the runtime environment.

### Non-root container user
The container runs as UID `65532:65532`. Running as non-root limits the blast radius of any container-level vulnerability.

### OIDC authentication (no stored credentials)
GitHub Actions authenticates to AWS using OpenID Connect rather than long-lived IAM access keys. A short-lived token is issued per workflow run and expires when the run ends — no credentials are ever stored in GitHub.

### Modular Terraform
Infrastructure is broken into isolated modules — `vpc`, `ecr`, `alb`, `ecs`, `acm` — each responsible for one concern. The root `main.tf` wires outputs between modules. This makes the infrastructure readable, testable, and extendable.

### Remote Terraform state
Terraform state is stored in an S3 bucket with versioning enabled. This allows both local and CI/CD pipeline runs to share the same state, making `terraform destroy` reliable from any environment.

---

## Repository Structure

```
ecs-gatus-project/
├── .github/
│   └── workflows/
│       ├── build-push.yml        # Builds and pushes Docker image to ECR
│       ├── terraform-apply.yml   # Provisions AWS infrastructure
│       └── terraform-destroy.yml # Tears down all AWS resources
├── app/
│   ├── Dockerfile                # Custom multistage build (golang → scratch)
│   ├── config.yaml               # Gatus endpoint configuration
│   ├── main.go                   # Gatus entrypoint
│   └── go.mod / go.sum           # Go dependencies
├── bootstrap/
│   ├── main.tf                   # OIDC provider and GitHub Actions IAM role
│   └── provider.tf               # AWS provider for bootstrap
├── infra/
│   ├── main.tf                   # Root module wiring all modules together
│   ├── provider.tf               # AWS provider configuration
│   ├── backend.tf                # S3 remote state configuration
│   ├── variables.tf              # Input variables
│   └── modules/
│       ├── vpc/                  # VPC, subnets, IGW, NAT Gateway, route tables
│       ├── ecr/                  # Container registry
│       ├── alb/                  # Load balancer, listeners, target group
│       ├── ecs/                  # Cluster, task definition, IAM, Fargate service
│       └── acm/                  # TLS certificate and DNS validation
└── README.md
```

---

## CI/CD Pipelines

All deployments are automated through GitHub Actions using OIDC — no AWS credentials are stored in GitHub.

```
Push to main (app/** changed)
         │
         ▼
    build-push.yml
    ├── OIDC → assume github-actions-role
    ├── docker build --platform linux/amd64
    ├── tag with :latest and :<commit-sha>
    └── push to ECR

Push to main (infra/** changed)
         │
         ▼
    terraform-apply.yml
    ├── OIDC → assume github-actions-role
    ├── terraform init  (reads state from S3)
    ├── terraform plan
    ├── terraform apply -auto-approve
    └── curl health check → fail pipeline if unhealthy

Manual trigger only
         │
         ▼
    terraform-destroy.yml
    ├── confirm = "yes" required
    ├── terraform plan -destroy
    └── terraform destroy -auto-approve
```

### Build and Push Pipeline
Triggers automatically when `app/` files change on `main`. Builds the image for `linux/amd64`, tags with both `latest` and the commit SHA for full version traceability.

![Build Pipeline](images/pipeline-build.png)

### Terraform Apply Pipeline
Triggers automatically when `infra/` files change on `main`, and can also be run manually via `workflow_dispatch`. Includes a post-deploy health check that fails the pipeline if the app is unreachable after deployment.

![Apply Pipeline](images/pipeline-apply.png)

### Terraform Destroy Pipeline
Manual only — never runs automatically. Requires typing `yes` as a confirmation input before any resources are touched.

![Destroy Pipeline](images/pipeline-destroy.png)

---

## Technologies

| Tool | Purpose |
|------|---------|
| AWS ECS Fargate | Serverless container runtime |
| AWS ECR | Private container registry |
| AWS ALB | Load balancing and TLS termination |
| AWS ACM | Managed TLS certificates |
| AWS Route53 | DNS management |
| AWS CloudWatch | Container log aggregation |
| AWS S3 | Remote Terraform state storage |
| Terraform | Infrastructure as Code |
| Docker | Multistage container build |
| GitHub Actions | CI/CD automation with OIDC |
| Go (Gatus) | Application runtime |

---

## Challenges and Lessons Learned

**Docker architecture mismatch** — Building on an Apple Silicon Mac (ARM) and deploying to Fargate (AMD64) caused silent failures at runtime. Fixed by adding `--platform linux/amd64` to the build command both locally and in the CI pipeline.

**ACM certificate destroy deadlock** — Changing the certificate's `subject_alternative_names` forced Terraform to replace it. By default, Terraform destroys the old cert first — but ACM refuses to delete a cert attached to an active ALB listener, causing an infinite hang. Fixed with `lifecycle { create_before_destroy = true }`.

**ECS task networking in private subnets** — Moving ECS tasks from public to private subnets required a NAT Gateway for outbound ECR pulls, a separate private route table, and `assign_public_ip = false` on the service. Each piece is required — any one missing causes silent deployment failures.

**Terraform state in CI/CD** — Without a remote backend, each pipeline run starts with empty state and loses it when the runner is destroyed. This made `terraform destroy` impossible via pipeline. Fixed by adding an S3 backend so state persists across all pipeline runs and local environments.

**ECR image timing** — Running `terraform apply` creates the ECR repository but ECS immediately tries to pull an image that does not exist yet, causing task failures. The correct order is: apply infrastructure → push image → force new ECS deployment.
