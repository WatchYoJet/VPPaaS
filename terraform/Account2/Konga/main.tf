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
variable "docker_image_user" { type = string }
variable "docker_image_pull_token" { type = string }
variable "kong_admin_url" { type = string }

resource "aws_instance" "konga" {
  ami                    = var.docker_base_ami
  instance_type          = "t3.small"
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "vockey"

  user_data = base64encode(templatefile("deploy.sh", {
    docker_username = var.docker_image_user
    docker_password = var.docker_image_pull_token
    kong_admin_url  = var.kong_admin_url
  }))
  user_data_replace_on_change = true

  tags = { Name = "vppas-konga" }
}

resource "aws_security_group" "instance" {
  name = "terraform-konga-account2-2026"
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
  value       = aws_instance.konga.public_dns
  description = "Konga admin UI endpoint (port 1337)"
}
