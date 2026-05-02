variable "db_username" {
  description = "The username for the database"
  type        = string
  sensitive   = true
  default     = "ie_project"
}
variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
  default     = "password"
}
variable "db_name" {
  description = "The name to use for the database"
  type        = string
  default     = "laas"
}

resource "aws_db_instance" "laas_database" {
  identifier_prefix      = "terraform-up-and-running"
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

output "address" {
  value       = aws_db_instance.laas_database.address
  description = "Connect to the database at this endpoint"
}

output "port" {
  value       = aws_db_instance.laas_database.port
  description = "The port the database is listening on"
}

resource "aws_security_group" "rds" {
  name = var.security_group_name
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

variable "security_group_name" {
  description = "The name of the security group"
  type        = string
  default     = "terraform-rds-instance"
}
