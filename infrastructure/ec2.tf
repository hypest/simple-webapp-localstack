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

# Key pair for EC2 access
resource "aws_key_pair" "rails_app" {
  key_name   = "rails-app-key"
  public_key = file("../scripts/rails-app-key.pub")

  tags = {
    Environment = "development"
    Project     = "simple-counter-app"
  }
}

# Launch template for Rails application
resource "aws_launch_template" "rails_app" {
  name_prefix   = "rails-app-"
  image_id      = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI (LocalStack will mock this)
  instance_type = "t3.micro"
  key_name      = aws_key_pair.rails_app.key_name

  vpc_security_group_ids = [aws_security_group.rails_app.id]

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    counter_queue_url   = aws_sqs_queue.counter_queue.url
    region              = "us-east-1"
    localstack_endpoint = "http://localhost:4566"
    app_image_uri       = var.app_image_uri
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "rails-app-instance"
      Environment = "development"
      Project     = "simple-counter-app"
    }
  }
}

# Auto Scaling Group for Rails application
resource "aws_autoscaling_group" "rails_app" {
  name                = "rails-app-asg"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.rails_app.arn]
  health_check_type   = "ELB"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.rails_app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "rails-app-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = "development"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "simple-counter-app"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "rails_app" {
  name               = "rails-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.rails_app.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name        = "rails-app-load-balancer"
    Environment = "development"
    Project     = "simple-counter-app"
  }
}

# Target group for the load balancer
resource "aws_lb_target_group" "rails_app" {
  name     = "rails-app-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name        = "rails-app-target-group"
    Environment = "development"
    Project     = "simple-counter-app"
  }
}

# Load balancer listener
resource "aws_lb_listener" "rails_app" {
  load_balancer_arn = aws_lb.rails_app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.rails_app.arn
      }
    }
  }
}
