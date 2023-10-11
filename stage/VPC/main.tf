terraform {
  backend "s3" {
    bucket         = "myterraform-bucket-state-park"
    key            = "stage/vpc/terraform.tfstate"
    region         = "ap-northeast-2"
    profile        = "terraform_user"
    dynamodb_table = "myTerraform-bucket-lock-park"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "terraform_user"
}
# Stage VPC
module "stage_vpc" {
  source = "github.com/sowoner/Terraform_Project_VPC"
  name   = "stage_vpc"
  cidr   = local.cidr

  azs              = local.azs
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  enable_dns_hostnames = "true"
  enable_dns_support   = "true"

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    "TerraformManaged" = "true"
  }
}
# SSH SG
module "SSH_SG" {
  source          = "github.com/sowoner/Terraform_Project_SG"
  name            = "SSH_SG"
  description     = "SSH Port Allow"
  vpc_id          = module.stage_vpc.vpc_id
  use_name_prefix = "false"

  ingress_with_cidr_blocks = [
    {
      from_port   = local.ssh_port
      to_port     = local.ssh_port
      protocol    = local.tcp_protocol
      description = "SSH Port Allow"
      cidr_blocks = local.all_network
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = local.any_port
      to_port     = local.any_port
      protocol    = local.any_protocol
      cidr_blocks = local.all_network
    }
  ]
}


# HTTP HTTPS SG
module "HTTP_HTTPS_SG" {
  source          = "github.com/sowoner/Terraform_Project_SG"
  name            = "HTTP_HTTPS_SG"
  description     = "HTTP, HTTPS Port Allow"
  vpc_id          = module.stage_vpc.vpc_id
  use_name_prefix = "false"

  ingress_with_cidr_blocks = [
    {
      from_port   = local.http_port
      to_port     = local.http_port
      protocol    = local.tcp_protocol
      description = "HTTP Port Allow"
      cidr_blocks = local.all_network
    },
    {
      from_port   = local.https_port
      to_port     = local.https_port
      protocol    = local.tcp_protocol
      description = "HTTPS Port Allow"
      cidr_blocks = local.all_network
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = local.any_port
      to_port     = local.any_port
      protocol    = local.any_protocol
      cidr_blocks = local.all_network
    }
  ]
}


# RDS SG
module "RDS_SG" {
  source          = "github.com/sowoner/Terraform_Project_SG"
  name            = "RDS_SG"
  description     = "DB Port Allow"
  vpc_id          = module.stage_vpc.vpc_id
  use_name_prefix = "false"

  ingress_with_cidr_blocks = [
    {
      from_port   = local.db_port
      to_port     = local.db_port
      protocol    = local.tcp_protocol
      description = "DB Port Allow"
      cidr_blocks = local.private_subnets[0]
    },
    {
      from_port   = local.db_port
      to_port     = local.db_port
      protocol    = local.tcp_protocol
      description = "DB Port Allow"
      cidr_blocks = local.private_subnets[1]
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = local.any_port
      to_port     = local.any_port
      protocol    = local.any_protocol
      cidr_blocks = local.all_network
    }
  ]
}
# BastionHost AWS KEY-Pair Data Source
data "aws_key_pair" "EC2-Key" {
  key_name = "EC2-key"
}
# BastionHost EIP
resource "aws_eip" "BastionHost_eip" {
  instance = aws_instance.BastionHost.id
  tags = {
    Name = "BastionHost_EIP"
  }
}

# BastionHost Instance ( 
resource "aws_instance" "BastionHost" {
  ami                         = "ami-0ea4d4b8dc1e46212"
  instance_type               = "t2.micro"
  key_name                    = data.aws_key_pair.EC2-Key.key_name
  subnet_id                   = module.stage_vpc.public_subnets[1]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.SSH_SG.security_group_id]

  tags = {
    Name = "BastionHost_Instance"
  }
}