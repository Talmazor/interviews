include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path = find_in_parent_folders("prod/terragrunt.hcl")
  expose = true
}

terraform {
  source = "../../modules/s3"
}

inputs = {
  bucket_name  = include.env.inputs.bucket_name
  common_tags  = include.env.inputs.common_tags
} 