variable "environment" {
  type        = string
  description = "The name of our deployment stage"
  default     = "production"
}

variable "domain_name" {
  type    = string
  default = "hamza-alsoodani.com"
}

variable "subdomain" {
  type    = string
  default = "tm"
}
