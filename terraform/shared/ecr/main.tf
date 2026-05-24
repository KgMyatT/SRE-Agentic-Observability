provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = var.project_name
    }
  }
}

variable "aws_region" { type = string }
variable "project_name" { type = string }

locals {
  repos = [
    "${var.project_name}-api",
    "${var.project_name}-worker",
    "${var.project_name}-alloy"
  ]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.repos)
  name     = each.value

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "repository_urls" {
  value = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

