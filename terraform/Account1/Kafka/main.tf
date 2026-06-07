terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_uuid" "kafka_cluster_id" {}

resource "aws_instance" "kafka" {
  ami                    = "ami-07ff62358b87c7116"
  instance_type          = "t3.small"
  count                  = 3
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "vockey"

  user_data                   = file("creation.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "vppas-kafka-${count.index}"
  }
}

resource "null_resource" "kafkaClusterSetup" {
  count      = 3
  depends_on = [aws_instance.kafka]

  connection {
    type        = "ssh"
    host        = aws_instance.kafka[count.index].public_dns
    user        = "ec2-user"
    private_key = file(pathexpand("~/.ssh/labsuser.pem"))
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = ["while [ ! -f /tmp/user_data_complete ]; do sleep 5; done"]
  }

  provisioner "file" {
    content = templatefile("setup.sh", {
      node_id           = count.index + 1
      cluster_uuid      = random_uuid.kafka_cluster_id.result
      my_dns            = aws_instance.kafka[count.index].public_dns
      controller_voters = join(",", [for idx, dns in aws_instance.kafka[*].public_dns : "${idx + 1}@${dns}:9093"])
    })
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh",
      "rm -f /tmp/setup.sh",
    ]
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-kafka-account1-${substr(random_uuid.kafka_cluster_id.result, 0, 8)}"
  lifecycle {
    ignore_changes = all
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9093
    to_port     = 9093
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

output "kafka_brokers" {
  description = "Kafka bootstrap servers string (comma-separated)"
  value       = join(",", [for dns in aws_instance.kafka[*].public_dns : "${dns}:9092"])
}
