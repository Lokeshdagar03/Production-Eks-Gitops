provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Production-EKS-GitOps"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
