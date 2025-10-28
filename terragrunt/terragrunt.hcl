locals {
  # Parse the path to get environment and component
  path_parts = split("/", path_relative_to_include())
  env        = local.path_parts[0]
  component  = local.path_parts[1]
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${get_env("AWS_REGION", "us-west-2")}"
}
EOF
}

# Generate backend configuration
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "${local.env}/${local.component}/terraform.tfstate"
    region         = "${get_env("AWS_REGION", "us-west-2")}"
    encrypt        = true
  }
}
EOF
}

# Common variables for all environments
inputs = {
  environment = local.env
  common_tags = {
    Environment = local.env
    Department  = "engineering"
    CreatedBy   = "terragrunt"
    Project     = "infrastructure"
    Component   = local.component
  }
} 