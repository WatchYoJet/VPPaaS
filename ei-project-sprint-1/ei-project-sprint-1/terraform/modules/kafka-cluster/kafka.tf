variable "nBroker" {
  description = "number of brokers"
  type        = number
  default     = 3
}

variable "basePath" {
  description = "Path for the kafka cluster module"
  type        = string
  default     = "modules/kafka-cluster/"
}

resource "aws_instance" "kafkaBroker" {
  ami                    = "ami-045269a1f5c90a6a0"
  instance_type          = "t2.small"
  count                  = var.nBroker
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "vockey"

  user_data = base64encode(templatefile("${var.basePath}creation.sh", {
    idBroker     = "${count.index}"
    totalBrokers = var.nBroker
  }))
  user_data_replace_on_change = true

  tags = {
    Name = "terraform-kafka.${count.index}"
  }
}

output "publicdnslist" {
  value = formatlist("%v", aws_instance.kafkaBroker.*.public_dns)
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
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2888
    to_port     = 2888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3888
    to_port     = 3888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9092
    to_port     = 9092
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
  description = "Kafka Cluster security group name"
  type        = string
  default     = "kafka-cluster"
}

resource "null_resource" "kafkaClusterSetup" {
  count = length(aws_instance.kafkaBroker)

  connection {
    type        = "ssh"
    host        = aws_instance.kafkaBroker[count.index].public_dns
    user        = "ec2-user"
    private_key = file("../labsuser.pem")
    timeout     = "30s"
  }

  provisioner "file" {
    content = templatefile("${var.basePath}setup.sh", {
      publicdnslist = join(" ", aws_instance.kafkaBroker[*].public_dns)
    })
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/user_data_complete ]; do sleep 5; done",
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh",
      "rm -rf /tmp/setup.sh",
    ]
  }
}
