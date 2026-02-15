# Root module - API Platform Infrastructure
# Provisions a containerized API on ECS Fargate with RDS PostgreSQL and ALB

provider "aws" {
  region = var.region
}

locals {
  environment = var.environment
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Networking - VPC, subnets, NAT gateway
module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = local.environment
  common_tags          = local.common_tags
}

# Database - RDS PostgreSQL
module "database" {
  source = "./modules/database"

  vpc_id      = module.networking.vpc_id
  subnet_ids  = module.networking.private_subnet_ids
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  environment = local.environment
  common_tags = local.common_tags
}

# ECS - Fargate cluster, ALB, and service
module "ecs" {
  source = "./modules/ecs"

  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  public_subnet_ids = module.networking.public_subnet_ids
  container_image   = var.container_image
  container_port    = 8080
  service_name      = "api"
  project_name      = var.project_name
  environment       = local.environment
  aws_region        = var.region
  db_host           = module.database.rds_endpoint
  db_port           = module.database.rds_port
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  common_tags       = local.common_tags
}
