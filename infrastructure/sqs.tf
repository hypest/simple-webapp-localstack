resource "aws_sqs_queue" "counter_queue" {
  name = "counter-queue"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_sqs_queue" "counter_queue_dlq" {
  name = "counter-queue-dlq"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
