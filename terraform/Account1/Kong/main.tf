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

resource "aws_instance" "kong" {
  ami                    = var.docker_base_ami
  instance_type          = "t3.small"
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "vockey"

  user_data = file("deploy.sh")

  user_data_replace_on_change = true

  tags = { Name = "vppas-kong" }
}

resource "aws_security_group" "instance" {
  name = "terraform-kong-account1-2026"
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
  value       = aws_instance.kong.public_dns
  description = "Kong gateway :8000, admin :8001"
}
