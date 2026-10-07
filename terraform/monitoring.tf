# ---------- Container logs ----------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/app"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role_policy" "ec2_write_logs" {
  name = "${var.project_name}-write-logs"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "WriteContainerLogsOnly"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.app.arn}:*"
    }]
  })
}

# ---------- Email alerts ----------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------- High-CPU alarm ----------
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "${var.project_name}-high-cpu"
  alarm_description = "CPU above ${var.cpu_alarm_threshold}% on ${var.server_name}"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions = {
    InstanceId = aws_instance.app.id
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.cpu_alarm_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
