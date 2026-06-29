variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "domain_name" {
  type = string
}

variable "subdomain" {
  type = string
}

variable "certificate_arn" {
  type = string
}
