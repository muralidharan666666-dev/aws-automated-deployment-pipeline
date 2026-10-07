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

output "log_group_name" {
  description = "CloudWatch log group for the container logs"
  value       = aws_cloudwatch_log_group.app.name
}

output "sns_topic_arn" {
  description = "SNS topic that sends alarm emails"
  value       = aws_sns_topic.alerts.arn
}
