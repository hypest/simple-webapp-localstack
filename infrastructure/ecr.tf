# ECR Repository for storing Docker images
resource "aws_ecr_repository" "rails_app" {
  name                 = "rails-counter-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "rails-counter-app-ecr"
    Environment = "development"
    Project     = "simple-counter-app"
  }
}

# ECR Repository Policy
resource "aws_ecr_repository_policy" "rails_app" {
  repository = aws_ecr_repository.rails_app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPullPush"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}
