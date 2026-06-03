#!/bin/bash
set -e

source ./access.sh

# helpers 

CompileCode() {
    sed -i "" "/quarkus.datasource.reactive.url/d" application.properties
    sed -i "" "/quarkus.container-image.group/d" application.properties
    echo "quarkus.container-image.group=$DockerUsername" >> application.properties
    echo "quarkus.datasource.reactive.url=mysql://$addressDB:3306/VPPaaS" >> application.properties
    cd ../../..
    esc=$'\e'
    DockerImage="$(grep -m 1 "<artifactId>" pom.xml | sed "s/<artifactId>//g;s/<\/artifactId>//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    DockerImageVersion="$(grep -m 1 "<version>" pom.xml | sed "s/<version>//g;s/<\/version>//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    ./mvnw clean package -Dquarkus.docker.buildx.platform=linux/arm64,linux/amd64
    cd ../..
}

DeployMicroservice() {
    sed -i "" "/sudo docker login/d" quarkus.sh
    sed -i "" "/sudo docker pull/d" quarkus.sh
    sed -i "" "/sudo docker run/d" quarkus.sh
    echo "sudo docker login -u \"$DockerUsername\" -p \"$DockerPassword\"" >> quarkus.sh
    echo "sudo docker pull $DockerUsername/$DockerImage:$DockerImageVersion" >> quarkus.sh
    echo "sudo docker run -d --name $DockerImage -p 8080:8080 $DockerUsername/$DockerImage:$DockerImageVersion" >> quarkus.sh
    terraform init
    terraform apply -replace="aws_instance.exampleDeployQuarkus" -auto-approve
    cd ../../..
}

GetAddress() {
    local tfdir=$1
    cd terraform/Quarkus-Terraform/$tfdir
    esc=$'\e'
    addr="$(terraform state show aws_instance.exampleDeployQuarkus | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    cd ../../..
    echo $addr
}

esc=$'\e'

# RDS 
echo " Deploying RDS..."
cd terraform/RDS-Terraform
terraform init && terraform apply -auto-approve
addressDB="$(terraform state show aws_db_instance.example | grep ' address' | sed "s/address//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "RDS address: $addressDB"
cd ../..

# Kafka 
echo " Deploying Kafka..."
cd terraform/Kafka
terraform init && terraform apply -auto-approve
addresskafka="$(terraform state show 'aws_instance.exampleKafkaConfiguration[0]' | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "Kafka address: $addresskafka"
cd ../..

# Ollama 
echo " Deploying Ollama..."
cd terraform/Ollama-Terraform
terraform init && terraform apply -auto-approve
addressOllama="$(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "Ollama address: $addressOllama"
cd ../..

# Telemetry 
echo " Building & deploying Telemetry..."
cd microservices/Telemetry/src/main/resources
sed -i "" "/kafka.bootstrap.servers/d" application.properties
echo "kafka.bootstrap.servers=$addresskafka:9092" >> application.properties
CompileCode
cd terraform/Quarkus-Terraform/telemetry
DeployMicroservice
TELEMETRY_ADDRESS=$(GetAddress telemetry)
echo "Telemetry address: $TELEMETRY_ADDRESS"

# AssetLink 
echo " Building & deploying AssetLink..."
cd microservices/AssetLink/src/main/resources
sed -i "" "/kafka.bootstrap.servers/d" application.properties
echo "kafka.bootstrap.servers=$addresskafka:9092" >> application.properties
sed -i "" "/telemetry.service.url/d" application.properties
echo "telemetry.service.url=http://$TELEMETRY_ADDRESS:8080" >> application.properties
CompileCode
cd terraform/Quarkus-Terraform/assetlink
DeployMicroservice
ASSETLINK_ADDRESS=$(GetAddress assetlink)
echo "AssetLink address: $ASSETLINK_ADDRESS"

# Prosumer 
echo " Building & deploying Prosumer..."
cd microservices/Prosumer/src/main/resources
CompileCode
cd terraform/Quarkus-Terraform/prosumer
DeployMicroservice

# UtilityOperator 
echo " Building & deploying UtilityOperator..."
cd microservices/UtilityOperator/src/main/resources
CompileCode
cd terraform/Quarkus-Terraform/utilityoperator
DeployMicroservice
UTILITYOPERATOR_ADDRESS=$(GetAddress utilityoperator)
echo "UtilityOperator address: $UTILITYOPERATOR_ADDRESS"

# FlexibilityEvent
echo " Building & deploying FlexibilityEvent..."
cd microservices/FlexibilityEvent/src/main/resources
sed -i "" "/kafka.bootstrap.servers/d" application.properties
echo "kafka.bootstrap.servers=$addresskafka:9092" >> application.properties
sed -i "" "/telemetry.service.url/d" application.properties
echo "telemetry.service.url=http://$TELEMETRY_ADDRESS:8080" >> application.properties
CompileCode
cd terraform/Quarkus-Terraform/flexibilityevent
DeployMicroservice
FLEXIBILITYEVENT_ADDRESS=$(GetAddress flexibilityevent)
echo "FlexibilityEvent address: $FLEXIBILITYEVENT_ADDRESS"

# EnergyAnalytics
echo " Building & deploying EnergyAnalytics..."
cd microservices/EnergyAnalytics/src/main/resources
sed -i "" "/kafka.bootstrap.servers/d" application.properties
echo "kafka.bootstrap.servers=$addresskafka:9092" >> application.properties
sed -i "" "/telemetry.service.url/d" application.properties
echo "telemetry.service.url=http://$TELEMETRY_ADDRESS:8080" >> application.properties
CompileCode
cd terraform/Quarkus-Terraform/energyanalytics
DeployMicroservice

# GridBalancing 
echo " Building & deploying GridBalancing..."
cd microservices/GridBalancing/src/main/resources
sed -i "" "/kafka.bootstrap.servers/d" application.properties
echo "kafka.bootstrap.servers=$addresskafka:9092" >> application.properties
sed -i "" "/telemetry.service.url/d" application.properties
echo "telemetry.service.url=http://$TELEMETRY_ADDRESS:8080" >> application.properties
sed -i "" "/utilityoperator.service.url/d" application.properties
echo "utilityoperator.service.url=http://$UTILITYOPERATOR_ADDRESS:8080" >> application.properties
sed -i "" "/assetlink.service.url/d" application.properties
echo "assetlink.service.url=http://$ASSETLINK_ADDRESS:8080" >> application.properties
CompileCode
cd terraform/Quarkus-Terraform/gridbalancing
DeployMicroservice

# FlexibilityForecasting (on Ollama EC2)
echo " Building & deploying FlexibilityForecasting..."
cd microservices/FlexibilityForecasting/src/main/resources
sed -i "" "/flexibilityevent.service.url/d" application.properties
echo "flexibilityevent.service.url=http://$FLEXIBILITYEVENT_ADDRESS:8080" >> application.properties
CompileCode
cd terraform/Ollama-Terraform
sed -i "" "/sudo docker login/d" creation.sh
sed -i "" "/sudo docker pull.*flexibilityforecasting/d" creation.sh
sed -i "" "/sudo docker run.*flexibilityforecasting/d" creation.sh
echo "sudo docker login -u \"$DockerUsername\" -p \"$DockerPassword\"" >> creation.sh
echo "sudo docker pull $DockerUsername/flexibilityforecasting:1.0.0-SNAPSHOT" >> creation.sh
echo "sudo docker run -d --name flexibilityforecasting --network=host $DockerUsername/flexibilityforecasting:1.0.0-SNAPSHOT" >> creation.sh
terraform apply -replace="aws_instance.ollamaInstance" -auto-approve
addressOllama="$(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "FlexibilityForecasting address: http://$addressOllama:8080"
cd ../..



# Kong
echo " Deploying Kong..."
cd terraform/KongTerraform
terraform init && terraform apply -auto-approve
addressKong="$(terraform state show aws_instance.exampleInstallKong | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g')"
echo "Kong address: $addressKong"
cd ../..

# Camunda
echo " Deploying Camunda..."
cd terraform/Camunda-Terraform
terraform init && terraform apply -auto-approve
addressCamunda="$(terraform state show aws_instance.exampleInstallCamundaEngine | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g')"
echo "Camunda address: $addressCamunda"
cd ../..

# Configure Kong Routes
echo " Configuring Kong Routes..."
# Wait a few seconds for Kong to be fully up

echo " Waiting for Kong API to become ready (this takes about 2-3 minutes for Docker and Postgres to boot)..."
until curl -s -f -o /dev/null --max-time 5 "http://$addressKong:8001"; do
    sleep 5
    echo -n "."
done
echo " Kong is ready!"

export KONG_ADMIN_URL="http://$addressKong:8001"
export PROSUMER_URL="http://$(GetAddress prosumer):8080"
export UTILITY_URL="http://$UTILITYOPERATOR_ADDRESS:8080"
export ASSETLINK_URL="http://$ASSETLINK_ADDRESS:8080"
export TELEMETRY_URL="http://$TELEMETRY_ADDRESS:8080"
export FLEXIBILITY_URL="http://$FLEXIBILITYEVENT_ADDRESS:8080"
export GRIDBALANCING_URL="http://$(GetAddress gridbalancing):8080"
export ENERGYANALYTICS_URL="http://$(GetAddress energyanalytics):8080"
export FORECASTING_URL="http://$addressOllama:8080"
cd terraform/KongTerraform
./configure_routes.sh
cd ../..

# Summary
echo ""
echo "================================================"
echo " SPRINT 2 DEPLOYMENT COMPLETE"
echo "================================================"

cd terraform/RDS-Terraform
echo "RDS:             $(terraform state show aws_db_instance.example | grep ' address' | sed "s/address//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):3306"
cd ../..

cd terraform/Kafka
echo "Kafka:           $(terraform state show 'aws_instance.exampleKafkaConfiguration[0]' | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):9092"
cd ../..

cd terraform/Ollama-Terraform
echo "Ollama:          $(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):11434"
echo "flexibilityforecasting: http://$(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):8080/q/swagger-ui/"
cd ../..

for svc in prosumer utilityoperator assetlink telemetry flexibilityevent energyanalytics gridbalancing; do
    cd terraform/Quarkus-Terraform/$svc
    addr="$(terraform state show aws_instance.exampleDeployQuarkus | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    echo "$svc:        http://$addr:8080/q/swagger-ui/"
    cd ../../..
done

cd terraform/KongTerraform
echo "Kong Admin:      http://$(terraform state show aws_instance.exampleInstallKong | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):8001"
echo "Kong Gateway:    http://$(terraform state show aws_instance.exampleInstallKong | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):8000"
cd ../..

cd terraform/Camunda-Terraform
echo "Camunda Operate: http://$(terraform state show aws_instance.exampleInstallCamundaEngine | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):8081"
cd ../..
