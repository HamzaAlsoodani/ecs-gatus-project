resource "aws_ecr_repository" "main" {
  name         = "gatus-repo"
  force_delete = true 

  tags = {
    Name = "gatus-ecr"
  }
}