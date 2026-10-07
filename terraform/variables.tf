variable "aws_region" {
  description = "AWS region to build everything in"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used in resource names"
  type        = string
  default     = "flask-app"
}

variable "server_name" {
  description = "Name tag of the EC2 server. Must match SERVER_NAME in the pipeline"
  type        = string
  default     = "flask-app-server"
}

variable "instance_type" {
  description = "EC2 size"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "IP range for the whole VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IP range for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications"
  type        = string
}

variable "cpu_alarm_threshold" {
  description = "CPU percentage that triggers the high-CPU alarm"
  type        = number
  default     = 70
}

variable "log_retention_days" {
  description = "How many days CloudWatch keeps the container logs"
  type        = number
  default     = 7
}
