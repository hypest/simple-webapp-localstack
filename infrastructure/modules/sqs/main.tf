resource "aws_sqs_queue" "this" {
  name = var.queue_name

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.queue_name}-dlq"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
