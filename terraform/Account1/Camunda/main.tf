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

resource "aws_instance" "camunda" {
  ami                    = "ami-07ff62358b87c7116"
  instance_type          = "t3.large"
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "vockey"

  user_data = file("deploy.sh")

  user_data_replace_on_change = true

  tags = { Name = "vppas-camunda" }
}

resource "aws_security_group" "instance" {
  name = "terraform-camunda-account1-2026"
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
  value       = aws_instance.camunda.public_dns
  description = "Camunda: API :8080, Operate :8081, Tasklist :8082"
}
