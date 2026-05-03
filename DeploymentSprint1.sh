#!/bin/bash
set -e  # stop on any error

source ./access.sh

# ── helpers ────────────────────────────────────────────────────────────────

CompileCode() {
    # Patch application.properties with the real DB address and docker group
    sed -i "/quarkus.datasource.reactive.url/d" application.properties
    sed -i "/quarkus.container-image.group/d" application.properties
    echo "quarkus.container-image.group=$DockerUsername" >> application.properties
    echo "quarkus.datasource.reactive.url=mysql://$addressDB:3306/VPPaaS" >> application.properties
    # Go up to the microservice root and build
    cd ../../..
    esc=$'\e'
    DockerImage="$(grep -m 1 "<artifactId>" pom.xml | sed "s/<artifactId>//g;s/<\/artifactId>//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    DockerImageVersion="$(grep -m 1 "<version>" pom.xml | sed "s/<version>//g;s/<\/version>//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    ./mvnw clean package -Dquarkus.docker.buildx.platform=linux/arm64,linux/amd64
    cd ../..
}

DeployMicroservice() {
    sed -i "/sudo docker login/d" quarkus.sh
    sed -i "/sudo docker pull/d" quarkus.sh
    sed -i "/sudo docker run/d" quarkus.sh
    echo "sudo docker login -u \"$DockerUsername\" -p \"$DockerPassword\"" >> quarkus.sh
    echo "sudo docker pull $DockerUsername/$DockerImage:$DockerImageVersion" >> quarkus.sh
    echo "sudo docker run -d --name $DockerImage -p 8080:8080 $DockerUsername/$DockerImage:$DockerImageVersion" >> quarkus.sh
    terraform init
    terraform apply -replace="aws_instance.exampleDeployQuarkus" -auto-approve
    cd ../..
}

esc=$'\e'

# ── 1. RDS ─────────────────────────────────────────────────────────────────
echo ">>> Deploying RDS..."
cd RDS-Terraform
terraform init && terraform apply -auto-approve
addressDB="$(terraform state show aws_db_instance.example | grep ' address' | sed "s/address//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "RDS address: $addressDB"
cd ..

# ── 2. Kafka ───────────────────────────────────────────────────────────────
echo ">>> Deploying Kafka..."
cd Kafka
terraform init && terraform apply -auto-approve
addresskafka="$(terraform state show 'aws_instance.exampleKafkaConfiguration[0]' | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "Kafka address: $addresskafka"
cd ..

# ── 3. Telemetry (needs Kafka address baked in) ───────────────────────────
echo ">>> Building & deploying Telemetry..."
cd microservices/Telemetry/src/main/resources
sed -i "/kafka.bootstrap.servers/d" application.properties
echo "kafka.bootstrap.servers=$addresskafka:9092" >> application.properties
CompileCode
cd Quarkus-Terraform/telemetry
DeployMicroservice

# ── 4. AssetLink ───────────────────────────────────────────────────────────
echo ">>> Building & deploying AssetLink..."
cd microservices/AssetLink/src/main/resources
CompileCode
cd Quarkus-Terraform/assetlink
DeployMicroservice

# ── 5. Prosumer ────────────────────────────────────────────────────────────
echo ">>> Building & deploying Prosumer..."
cd microservices/Prosumer/src/main/resources
CompileCode
cd Quarkus-Terraform/prosumer
DeployMicroservice

# ── 6. UtilityOperator ────────────────────────────────────────────────────
echo ">>> Building & deploying UtilityOperator..."
cd microservices/UtilityOperator/src/main/resources
CompileCode
cd Quarkus-Terraform/utilityoperator
DeployMicroservice

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo " SPRINT 1 DEPLOYMENT COMPLETE"
echo "════════════════════════════════════════════════"

cd RDS-Terraform
echo "RDS:             $(terraform state show aws_db_instance.example | grep ' address' | sed "s/address//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):3306"
cd ..

cd Kafka
echo "Kafka:           $addresskafka:9092"
cd ..

for svc in prosumer utilityoperator assetlink telemetry; do
    cd Quarkus-Terraform/$svc
    addr="$(terraform state show aws_instance.exampleDeployQuarkus | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    echo "$svc: http://$addr:8080/q/swagger-ui/"
    cd ../..
done
