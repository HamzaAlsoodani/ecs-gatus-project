output "target_group_arn" {
  description = "The ARN of the Target Group"
  value       = aws_lb_target_group.main.arn
}

output "alb_security_group_id" {
  description = "The ID of the ALB Security Group"
  value       = aws_security_group.main.id
}

output "aws_lb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "aws_lb_target_group_arn" {
  description = "The ARN of the Application Load Balancer Target Group"
  value       = aws_lb_target_group.main.arn

}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The hosted zone ID of the ALB"
  value       = aws_lb.main.zone_id
}
