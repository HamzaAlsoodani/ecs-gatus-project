terraform {
  # WHAT: Declares the providers this Terraform configuration depends on.
  # WHY: Terraform needs to know which plugins to install before it can create AWS resources.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}
