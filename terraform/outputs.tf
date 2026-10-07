output "app_url" {
  description = "Open this in a browser after the pipeline deploys"
  value       = "http://${aws_instance.app.public_ip}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "ecr_repository_url" {
  description = "Where the pipeline pushes images"
  value       = aws_ecr_repository.app.repository_url
}

output "vpc_id" {
  description = "ID of the project VPC"
  value       = aws_vpc.main.id
}
