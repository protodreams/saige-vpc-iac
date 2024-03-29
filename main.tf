provider "aws" {
  region = "us-east-1"
}

variable "environment" {
  description = "The environment to deploy to"
  type        = string
  default     = "dev"
}
data "aws_availability_zones" "available" {}

locals {
  name   = "saige-vpc"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
     Name= local.name
  }
}

resource "aws_iam_role" "saige_ssm_role" {
  name = "saige_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = local.name
  cidr   = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]

  private_subnet_names = ["Private Subnet 1", "Private Subnet 2", "Private Subnet 3"]
  public_subnet_names = ["Public Subnet 1", "Public Subnet 2", "Public Subnet 3"]

  enable_dns_hostnames = true
  enable_dns_support   = true
}

output "vpc_private_subnet_ids" {
  value = module.vpc.private_subnets[0]
}

output "vpc_public_subnet_ids" {
  value = module.vpc.public_subnets[0]
}

resource "aws_nat_gateway" "nat" {
  subnet_id = module.vpc.public_subnets[0]
  allocation_id = aws_eip.nat_eip.id
  tags = {
    "Name" = "saige_nat_gateway"
  }
}

resource "aws_eip" "nat_eip" {
}

output "nat_gateway_ip" {
  value = aws_nat_gateway.nat.public_ip
}

resource "aws_route" "private1" {
  route_table_id = module.vpc.private_route_table_ids[0]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route" "private2" {
  route_table_id = module.vpc.private_route_table_ids[1]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route" "private3" {
  route_table_id = module.vpc.private_route_table_ids[2]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = module.vpc.private_route_table_ids
}

resource "aws_security_group" "saige_vpc_sg" {
  name        = "saige-vpc-sg"
  description = "Default Security Group for connecting from prem to cloud"
  vpc_id      = module.vpc.vpc_id

  dynamic ingress {
    for_each = var.ingress_ports
    content {
    from_port   = ingress.value.from_port
    to_port     = ingress.value.to_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "saige-vpc-sg"
  }
}

output "saige_vpc_sg_id" {
  value = aws_security_group.saige_vpc_sg.id
}

data "aws_subnets" public_subnets {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
  tags = {
    Name = "Public Subnet*"
  }
}


# install a bastion host
resource "aws_instance" "bastion-host" {
  ami = var.bastion_ami
  instance_type = var.bastion_type
  subnet_id = data.aws_subnets.public_subnets.ids[0]
  security_groups = [aws_security_group.saige_vpc_sg.id]
  key_name = "saige-dev"
  associate_public_ip_address = true
  # count = var.environment == "bastion" ? 1:0
   tags = {
      Name = "Bastion Host"
  }
}

output "bastion-host" {
  value = aws_instance.bastion-host.public_dns

  depends_on = [
    aws_instance.bastion-host
  ]
}