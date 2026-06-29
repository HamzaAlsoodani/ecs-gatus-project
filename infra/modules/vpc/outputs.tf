output "vpc_id" {
  description = "The ID of the VPC created by this module"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets created by this module"
  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
  ]
}

