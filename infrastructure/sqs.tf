resource "aws_sqs_queue" "counter_queue" {
  name = "counter-queue"

  tags = {
    Environment = "development"
    Project     = "simple-counter-app"
  }
}

resource "aws_sqs_queue" "counter_queue_dlq" {
  name = "counter-queue-dlq"

  tags = {
    Environment = "development"
    Project     = "simple-counter-app"
  }
}
