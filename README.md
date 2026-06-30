# Gatus Health Monitoring on AWS ECS Fargate

> A production-grade health monitoring platform deployed on AWS using Terraform, Docker, and GitHub Actions — built from the ground up with security and automation as first principles.

![Architecture](images/architecture.png)

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

```
User
 │
 ▼
Route53 (DNS)
 │
 ▼
Application Load Balancer  ←── ACM (TLS certificate)
 │         (public subnets)
 ▼
ECS Fargate Task           ←── ECR (container image)
 │         (private subnets)
 ▼
NAT Gateway
 │         (outbound only)
 ▼
Internet (ECR pulls, health checks)
```

Traffic enters through Route53, hits the ALB in the public subnets, and is forwarded to the Gatus container running in the private subnets. The container never has a public IP — all outbound traffic (image pulls, health checks) exits through a NAT Gateway.

---

## Key Design Decisions

### Private ECS workloads
ECS tasks run in private subnets with no public IP assigned. The ALB is the single entry point, meaning the container is never directly reachable from the internet. This follows AWS security best practices and reduces the attack surface significantly.

### Custom multistage Dockerfile
Rather than using the official Gatus image, I wrote a custom multistage Dockerfile:

- **Stage 1 (builder):** Uses `golang:1.26-alpine` to compile the Go source into a single static binary
- **Stage 2 (runtime):** Uses `scratch` — an empty base image containing only the compiled binary and config

This reduces the final image size by over 95% compared to a standard build image and removes all unnecessary tooling from the runtime environment.

### Non-root container user
The container runs as UID `65532:65532`. Running as non-root limits the blast radius of any container-level vulnerability.

### OIDC authentication (no stored credentials)
GitHub Actions authenticates to AWS using OpenID Connect rather than long-lived IAM access keys. A short-lived token is issued per workflow run, scoped to the minimum required permissions.

### Modular Terraform
Infrastructure is broken into isolated modules — `vpc`, `ecr`, `alb`, `ecs`, `acm` — each responsible for one concern. The root `main.tf` wires outputs between modules. This makes the infrastructure readable, testable, and extendable.

---

## Repository Structure

```
ecs-gatus-project/
├── app/
│   ├── Dockerfile          # Custom multistage build
│   ├── config.yaml         # Gatus endpoint configuration
│   ├── main.go             # Gatus entrypoint
│   └── go.mod / go.sum     # Go dependencies
├── infra/
│   ├── main.tf             # Root module wiring all modules together
│   ├── provider.tf         # AWS provider configuration
│   ├── variables.tf        # Input variables
│   └── modules/
│       ├── vpc/            # VPC, subnets, IGW, NAT Gateway, route tables
│       ├── ecr/            # Container registry
│       ├── alb/            # Load balancer, listeners, target group
│       ├── ecs/            # Cluster, task definition, IAM, service
│       └── acm/            # TLS certificate and DNS validation
├── images/
│   ├── architecture.png
│   └── demo.gif
└── README.md
```

---

## CI/CD Pipelines

All deployments are automated through GitHub Actions. There are three workflows:

### Docker Build & Push
Triggers on every push to `main`. Builds the container image for `linux/amd64`, tags it with both `latest` and the commit SHA, and pushes to ECR.

![Build Pipeline](images/pipeline-build.png)

### Terraform Apply
Manually triggered. Initialises Terraform, runs `terraform plan`, and applies infrastructure changes to AWS.

![Apply Pipeline](images/pipeline-apply.png)

### Terraform Destroy
Manually triggered. Generates a destroy plan and tears down all AWS resources cleanly.

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
| Terraform | Infrastructure as Code |
| Docker | Multistage container build |
| GitHub Actions | CI/CD automation |
| Go (Gatus) | Application runtime |

---

## Challenges and Lessons Learned

**Docker architecture mismatch** — Building on an Apple Silicon Mac (ARM) and deploying to Fargate (AMD64) caused silent failures. Fixed by adding `--platform linux/amd64` to the build command.

**ACM certificate destroy deadlock** — Changing the certificate's `subject_alternative_names` forced Terraform to replace it. By default, Terraform destroys the old cert first — but ACM refuses to delete a cert attached to an active ALB listener, causing an infinite hang. Fixed with `lifecycle { create_before_destroy = true }`.

**ECS task networking** — Moving ECS tasks from public to private subnets required a NAT Gateway for outbound ECR pulls, a separate private route table, and `assign_public_ip = false` on the service. Each piece is required — any one missing breaks the deployment silently.

**ECR image timing** — Running `terraform apply` creates the ECR repository but ECS immediately tries to pull an image that doesn't exist yet, causing task failures. Fixed by applying infrastructure first, then pushing the image, then forcing a new ECS deployment.
