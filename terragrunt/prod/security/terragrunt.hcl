include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path = find_in_parent_folders("prod/terragrunt.hcl")
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "../../modules/security"
}

inputs = {
  vpc_id         = dependency.vpc.outputs.vpc_id
  allowed_ports  = include.env.inputs.allowed_ports
  common_tags    = include.env.inputs.common_tags
} 