variable "basePath" {
  description = "Path for the kafka cluster module"
  type        = string
  default     = "modules/ollama/"
}

resource "aws_instance" "ollamaConfiguration" {
  ami                    = "ami-0889a44b331db0194"
  instance_type          = "t2.large"
  count                  = 1
  vpc_security_group_ids = [aws_security_group.instance.id]
  root_block_device {
    volume_size = 24 # In Gb
  }
  key_name                    = "vockey"
  user_data                   = file("${var.basePath}creation.sh")
  user_data_replace_on_change = true
  tags = {
    Name = "terraform-ollama"
  }
}

resource "aws_security_group" "instance" {
  name = var.security_group_name
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 11434
    to_port     = 11434
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

variable "security_group_name" {
  description = "The name of the security group"
  type        = string
  default     = "terraform-ollama-instance"
}

output "address" {
  value       = aws_instance.ollamaConfiguration[*].public_dns
  description = "Address of the Kafka EC2 machine with ollama"
}
