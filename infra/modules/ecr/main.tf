resource "aws_ecr_repository" "this" {
  name                 = "${var.project}-${var.image_name}"
  # Environment tags (dev, staging, prod) are overwritten on each promotion.
  # SHA tags are unique per build so effectively immutable in practice.
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.project}-${var.image_name}" }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.retention_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.retention_count
      }
      action = { type = "expire" }
    }]
  })
}
