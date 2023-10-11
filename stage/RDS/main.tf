terraform {
  backend "s3" {
    bucket         = "myterraform-bucket-state-park"
    key            = "stage/rds/terraform.tfstate"
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
module "app1_db" {
  source                              = "github.com/sowoner/Terraform_Project_RDS"
  identifier                          = "stage-app1-db" # 식별이름 : 알파벳 소문자, 하이픈만 사용가능
  engine                              = "mysql"
  engine_version                      = "5.7.42"
  instance_class                      = "db.t3.micro"
  allocated_storage                   = 5
  multi_az                            = false
  iam_database_authentication_enabled = true
  manage_master_user_password         = false
  skip_final_snapshot                 = true
  family                              = "mysql5.7"
  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  major_engine_version = "5.7"
  db_name              = "webdb"
  username             = "admin"
  password             = "RDSterraform123!"
  port                 = "3306"
  # DB subnet group & DB Security-Group
  db_subnet_group_name   = data.terraform_remote_state.vpc_remote_data.outputs.database_subnet_group
  subnet_ids             = data.terraform_remote_state.vpc_remote_data.outputs.database_subnets
  vpc_security_group_ids = [data.terraform_remote_state.vpc_remote_data.outputs.RDS_SG]
}