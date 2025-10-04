# Data source to get the default VPC (LocalStack creates one automatically)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for the Rails application
resource "aws_security_group" "rails_app" {
  name        = "rails-app-sg"
  description = "Security group for Rails application"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "rails-app-security-group"
    Environment = "development"
    Project     = "simple-counter-app"
  }
}

# Generate SSH key pair using Terraform
resource "tls_private_key" "rails_app" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key pair for EC2 access
resource "aws_key_pair" "rails_app" {
  key_name   = "rails-app-key"
  public_key = tls_private_key.rails_app.public_key_openssh

  tags = {
    Environment = "development"
    Project     = "simple-counter-app"
  }
}

# Simple EC2 instance for local development (LocalStack free friendly)
resource "aws_instance" "rails_app" {
  ami                    = "ami-0c02fb55956c7d316" # mocked by LocalStack
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.rails_app.key_name
  vpc_security_group_ids = [aws_security_group.rails_app.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  user_data = templatefile("${path.module}/user-data.sh", {
    counter_queue_url   = aws_sqs_queue.counter_queue.url
    region              = "us-east-1"
    localstack_endpoint = "http://localhost:4566"
    app_image_uri       = var.app_image_uri
  })

  tags = {
    Name        = "rails-app-instance"
    Environment = "development"
    Project     = "simple-counter-app"
  }
}
