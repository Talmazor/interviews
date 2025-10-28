include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path = find_in_parent_folders("prod/terragrunt.hcl")
  expose = true
}

terraform {
  source = "../../modules/vpc"
}

inputs = {
  vpc_cidr            = include.env.inputs.vpc_cidr
  azs                 = include.env.inputs.azs
  public_subnet_cidrs = include.env.inputs.public_subnet_cidrs
  private_subnet_cidrs = include.env.inputs.private_subnet_cidrs
  common_tags         = include.env.inputs.common_tags
} 