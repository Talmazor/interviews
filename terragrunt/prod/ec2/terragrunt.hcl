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

dependency "security" {
  config_path = "../security"
}

terraform {
  source = "../../modules/ec2"
}

inputs = {
  instances    = include.env.locals.ec2_instances
  common_tags  = include.env.inputs.common_tags
}