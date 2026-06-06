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

variable "docker_image_user" { type = string }
variable "docker_image_pull_token" { type = string }
variable "flexibilityevent_url" { type = string }

resource "aws_instance" "ollama" {
  ami                    = "ami-0889a44b331db0194"
  instance_type          = "t2.large"
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "vockey"

  root_block_device {
    volume_size = 24
  }

  user_data = base64encode(templatefile("creation.sh", {
    docker_username      = var.docker_image_user
    docker_password      = var.docker_image_pull_token
    flexibilityevent_url = var.flexibilityevent_url
  }))
  user_data_replace_on_change = true

  tags = { Name = "vppas-ollama" }
}

resource "aws_security_group" "instance" {
  name = "terraform-ollama-account2-2026"
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
  value       = aws_instance.ollama.public_dns
  description = "Ollama/FlexibilityForecasting endpoint (Ollama:11434, FlexForecasting:8080)"
}
