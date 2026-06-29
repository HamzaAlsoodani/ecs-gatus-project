output "cluster_id" {
  description = "The ECS cluster ID"
  value       = aws_ecs_cluster.cluster.id
}

output "service_name" {
  description = "The ECS service name"
  value       = aws_ecs_service.main.name
}

output "task_security_group_id" {
  description = "The security group used by ECS tasks"
  value       = aws_security_group.ecs_tasks_sg.id
}

output "log_group_name" {
  description = "The CloudWatch log group used by ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}
