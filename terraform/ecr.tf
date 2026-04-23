# ECR repositories are shared across environments — each env pushes images
# tagged with its own name + git SHA (e.g. "dev-abc1234"), so a single repo
# holds images for all three envs without them interfering with each other.

resource "aws_ecr_repository" "backend" {
  name                 = "todo-pipeline/backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    # Scan on push catches known CVEs before the image is ever deployed
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = "todo-pipeline/frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# Lifecycle policy: keep the 10 most recent images per env prefix and delete
# older ones so the registry doesn't accumulate unbounded storage costs.
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images per environment"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-", "staging-", "prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images per environment"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-", "staging-", "prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}
