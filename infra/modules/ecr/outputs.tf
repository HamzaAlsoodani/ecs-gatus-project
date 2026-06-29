output "repository_url" {
  value       = aws_ecr_repository.main.repository_url
  description = "The URL of the ECR repository"
}