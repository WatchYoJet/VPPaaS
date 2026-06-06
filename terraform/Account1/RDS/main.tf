terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "db_username" {
  type      = string
  sensitive = true
  default   = "teste"
}
variable "db_password" {
  type      = string
  sensitive = true
  default   = "testeteste"
}
variable "db_name" {
  type    = string
  default = "VPPaaS"
}

resource "aws_db_instance" "example" {
  identifier_prefix      = "vppas2026"
  engine                 = "mysql"
  allocated_storage      = 20
  instance_class         = "db.t4g.micro"
  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
}

resource "aws_security_group" "rds" {
  name = "terraform-rds-account1-2026"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "address" {
  value       = aws_db_instance.example.address
  description = "RDS endpoint"
}
output "port" {
  value       = aws_db_instance.example.port
  description = "RDS port"
}
