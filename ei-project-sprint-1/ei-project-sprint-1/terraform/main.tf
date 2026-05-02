terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket                  = "terraform-s3-2025-05-05"
    key                     = "terraform.tfstate"
    region                  = "us-east-1"
    shared_credentials_file = "../.aws/credentials"
  }
}

provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["../.aws/credentials"]
}

variable "nBroker" {
  description = "number of brokers"
  type        = number
  default     = 3
}

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

variable "docker_image_user" {
  description = "The username to use for the docker image"
  type        = string
  default     = "docker_image_user"
}

variable "docker_image_pull_token" {
  description = "The password/token to use to pull the docker image"
  type        = string
  default     = "password"
}

variable "docker_image_create_token" {
  description = "The password/token to use to create the docker image"
  type        = string
  default     = "password"
}

module "kafka-cluster" {
  source  = "./modules/kafka-cluster"
  nBroker = var.nBroker
}

module "rds" {
  source      = "./modules/rds"
  db_username = var.db_username
  db_password = var.db_password
  db_name     = var.db_name
}

module "ollama" {
  source = "./modules/ollama"
}

output "kafka_ips" {
  value = module.kafka-cluster.publicdnslist
}

output "rds_address" {
  value = module.rds.address
}

output "rds_port" {
  value = module.rds.port
}

output "ollama_address" {
  value = module.ollama.address
}

module "purchases" {
  source                    = "./modules/purchases"
  kafka_brokers             = module.kafka-cluster.publicdnslist
  rds_address               = module.rds.address
  rds_port                  = module.rds.port
  db_username               = var.db_username
  db_password               = var.db_password
  db_name                   = var.db_name
  docker_image_create_token = var.docker_image_create_token
  docker_image_pull_token   = var.docker_image_pull_token
  docker_image_user         = var.docker_image_user

  depends_on = [
    module.kafka-cluster,
    module.rds,
  ]
}

output "purchasesAddress" {
  value = module.purchases.purchasesAddress
}


module "customer" {
    source = "./modules/customer"
    rds_address = module.rds.address
    rds_port = module.rds.port
    db_username = var.db_username
    db_password = var.db_password
    db_name = var.db_name
    docker_image_create_token = var.docker_image_create_token
    docker_image_pull_token = var.docker_image_pull_token
    docker_image_user = var.docker_image_user

    depends_on = [  
        module.rds,
    ]
}

output "customerAddress" {
  value = module.customer.customerAddress
}

module "shop" {
    source = "./modules/shop"
    rds_address = module.rds.address
    rds_port = module.rds.port
    db_username = var.db_username
    db_password = var.db_password
    db_name = var.db_name
    docker_image_create_token = var.docker_image_create_token
    docker_image_pull_token = var.docker_image_pull_token
    docker_image_user = var.docker_image_user

    depends_on = [  
        module.rds,
    ]
}

output "shopAddress" {
  value = module.shop.shopAddress
}

module "loyaltycard" {
  source                    = "./modules/loyaltycard"
  rds_address               = module.rds.address
  rds_port                  = module.rds.port
  db_username               = var.db_username
  db_password               = var.db_password
  db_name                   = var.db_name
  docker_image_create_token = var.docker_image_create_token
  docker_image_pull_token   = var.docker_image_pull_token
  docker_image_user         = var.docker_image_user

  depends_on = [
    module.rds,
  ]
}

output "loyaltyCardAddress" {
  value = module.loyaltycard.loyaltyCardAddress
}

module "discountCoupon" {
    source = "./modules/discount-coupon"
    kafka_brokers = module.kafka-cluster.publicdnslist
    rds_address = module.rds.address
    rds_port = module.rds.port
    db_username = var.db_username
    db_password = var.db_password
    db_name = var.db_name
    docker_image_create_token = var.docker_image_create_token
    docker_image_pull_token = var.docker_image_pull_token
    docker_image_user = var.docker_image_user

    depends_on = [  
        module.kafka-cluster,
        module.rds,
    ]
}

output "discountCouponAddress" {
  value = module.discountCoupon.discountCouponAddress
}

module "crossSellingRecommendation" {
    source = "./modules/cross-selling-recommendation"
    kafka_brokers = module.kafka-cluster.publicdnslist
    rds_address = module.rds.address
    rds_port = module.rds.port
    db_username = var.db_username
    db_password = var.db_password
    db_name = var.db_name
    docker_image_create_token = var.docker_image_create_token
    docker_image_pull_token = var.docker_image_pull_token
    docker_image_user = var.docker_image_user

    depends_on = [  
        module.kafka-cluster,
        module.rds,
    ]
}

output "CrossSellingRecommendationAddress" {
  value = module.crossSellingRecommendation.CrossSellingRecommendationAddress
}

module "selledProduct" {
  source                    = "./modules/selled-product"
  kafka_brokers             = module.kafka-cluster.publicdnslist
  rds_address               = module.rds.address
  rds_port                  = module.rds.port
  db_username               = var.db_username
  db_password               = var.db_password
  db_name                   = var.db_name
  docker_image_create_token = var.docker_image_create_token
  docker_image_pull_token   = var.docker_image_pull_token
  docker_image_user         = var.docker_image_user

  depends_on = [
    module.kafka-cluster,
    module.rds,
  ]
}

output "selledProductAddress" {
  value = module.selledProduct.selledProductAddress
}
