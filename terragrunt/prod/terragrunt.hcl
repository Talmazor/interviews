include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

locals {
  # Instance type configurations
  instance_types = {
    web = {
      type     = "t2.micro"
      volume   = 20
      subnet   = "public"
      ami      = "ami-0c55b159cbfafe1f0"
    },
    app = {
      type     = "t2.medium"
      volume   = 50
      subnet   = "private"
      ami      = "ami-0c55b159cbfafe1f0"
    },
    db = {
      type     = "t2.large"
      volume   = 100
      subnet   = "private"
      ami      = "ami-0c55b159cbfafe1f0"
    }
  }

  # Instance configurations
  instance_configs = {
    web = {
      count     = 3
      prefix    = "web-server"
      type      = "web"
    },
    app = {
      count     = 2
      prefix    = "app-server"
      type      = "app"
    },
    db = {
      count     = 1
      prefix    = "db-server"
      type      = "db"
    }
  }

  # Generate EC2 instances dynamically
  ec2_instances = merge([
    for instance_type, config in local.instance_configs : {
      for i in range(config.count) : "${instance_type}_${i + 1}" => {
        name              = "${config.prefix}-${i + 1}"
        type              = config.type
        ami_id            = local.instance_types[config.type].ami
        instance_type     = local.instance_types[config.type].type
        subnet_id         = local.instance_types[config.type].subnet == "public" ? 
                          dependency.vpc.outputs.public_subnet_ids["public-${i}"] : 
                          dependency.vpc.outputs.private_subnet_ids["private-${i}"]
        security_group_ids = [dependency.security.outputs.security_group_id]
        key_name          = "my-key"
        volume_size       = local.instance_types[config.type].volume
      }
    }
  ]...)
}

# Environment-specific variables
inputs = {
  vpc_cidr            = "10.0.0.0/16"
  azs                 = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  allowed_ports = {
    ssh = {
      port        = 22
      description = "SSH access"
    },
    http = {
      port        = 80
      description = "HTTP access"
    },
    https = {
      port        = 443
      description = "HTTPS access"
    }
  }
  bucket_name = "my-company-data-bucket-prod"
} 