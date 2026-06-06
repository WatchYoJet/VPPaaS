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

variable "docker_base_ami" { type = string }
variable "rds_address" { type = string }
variable "rds_port" {
  type    = number
  default = 3306
}
variable "db_username" {
  type    = string
  default = "teste"
}
variable "db_password" {
  type    = string
  default = "testeteste"
}
variable "db_name" {
  type    = string
  default = "VPPaaS"
}
variable "docker_image_user" { type = string }
variable "docker_image_pull_token" { type = string }
variable "kafka_brokers" { type = string }

resource "aws_instance" "telemetry" {
  ami                    = var.docker_base_ami
  instance_type          = "t3.small"
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "vockey"

  user_data = base64encode(templatefile("startup.sh", {
    docker_username = var.docker_image_user
    docker_password = var.docker_image_pull_token
    rds_address     = var.rds_address
    rds_port        = var.rds_port
    db_username     = var.db_username
    db_password     = var.db_password
    db_name         = var.db_name
    kafka_brokers   = var.kafka_brokers
  }))
  user_data_replace_on_change = true

  tags = { Name = "vppas-telemetry" }
}

resource "aws_security_group" "instance" {
  name = "terraform-telemetry-account1-2026"
  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "public_dns" {
  value       = aws_instance.telemetry.public_dns
  description = "Telemetry service endpoint (port 8080)"
}
