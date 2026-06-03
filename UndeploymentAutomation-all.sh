#!/bin/bash

source ./access.sh

cd terraform/Quarkus-Terraform/gridbalancing
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/energyanalytics
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/flexibilityevent
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/utilityoperator
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/prosumer
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/assetlink
terraform init && terraform destroy -auto-approve
cd ../../..

cd terraform/Quarkus-Terraform/telemetry
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

cd terraform/KongaTerraform
terraform init && terraform destroy -auto-approve
cd ../..

cd terraform/Camunda-Terraform
terraform init && terraform destroy -auto-approve
cd ../..
