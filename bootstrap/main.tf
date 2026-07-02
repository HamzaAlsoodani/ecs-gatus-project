resource "aws_s3_bucket" "tfstate" {
  bucket        = "hamza-gatus-tfstate"
  force_destroy = false

  tags = {
    Name = "gatus-tfstate"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:HamzaAlsoodani/ecs-gatus-project:*"
          }
        }
      }
    ]
  })
}

# AdministratorAccess is used here for simplicity. In production this should
# be scoped to only the services Terraform needs (ECR, ECS, ALB, VPC, IAM etc).
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}
