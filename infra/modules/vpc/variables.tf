# WHAT: Environment label passed down from the root module.
# WHY: It keeps resource names consistent across production, staging, or dev.
variable "environment" {
  type        = string
  description = "The deployment stage (e.g., production, staging) passed from the root"
}
