#!/bin/bash
source ./access.sh

cd terraform/Quarkus-Terraform/group-c
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/group-b
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/group-a
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Ollama-Terraform
terraform init && terraform destroy -auto-approve
cd ../..

cd terraform/Kafka
terraform init && terraform destroy -auto-approve
cd ../..

cd terraform/RDS-Terraform
terraform init && terraform destroy -auto-approve
cd ../..

cd terraform/KongTerraform
terraform init && terraform destroy -auto-approve
cd ../..

cd terraform/Camunda-Terraform
terraform init && terraform destroy -auto-approve
cd ../..
