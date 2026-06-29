variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "The subnets where the Gatus containers will actually run"
  type        = list(string)
}
variable "private_subnet_ids" {
  description = "The subnets where the Gatus containers will actually run"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Needed so the container only accepts traffic from the Load Balancer"
  type        = string
}

variable "target_group_arn" {
  description = "Needed so the ECS Service can register the container IPs"
  type        = string
}

variable "ecr_image_url" {
  description = "The full URL of your Gatus Docker image"
  type        = string
}