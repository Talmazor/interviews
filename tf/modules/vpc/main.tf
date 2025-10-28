resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "main-vpc"
    }
  )
}

resource "aws_subnet" "public" {
  for_each = {
    for idx, cidr in var.public_subnet_cidrs : 
    "public-${idx}" => {
      cidr = cidr,
      az   = var.azs[idx]
    }
  }
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "public-subnet-${each.key}"
      Type = "Public"
    }
  )
}

resource "aws_subnet" "private" {
  for_each = {
    for idx, cidr in var.private_subnet_cidrs : 
    "private-${idx}" => {
      cidr = cidr,
      az   = var.azs[idx]
    }
  }
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.common_tags,
    {
      Name = "private-subnet-${each.key}"
      Type = "Private"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
  Common_tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
} 