#!/bin/bash
set -e

source ./access.sh

esc=$'\e'

# RDS
echo " Deploying RDS..."
cd terraform/RDS-Terraform
terraform init && terraform apply -auto-approve
addressDB="$(terraform state show aws_db_instance.example | grep ' address' | sed "s/address//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "RDS address: $addressDB"
cd ../..

# Kafka cluster (3 brokers)
echo " Deploying Kafka cluster..."
cd terraform/Kafka
terraform init && terraform apply -auto-approve
broker0="$(terraform state show 'aws_instance.exampleKafkaConfiguration[0]' | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
broker1="$(terraform state show 'aws_instance.exampleKafkaConfiguration[1]' | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
broker2="$(terraform state show 'aws_instance.exampleKafkaConfiguration[2]' | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
addresskafka="$broker0:9092,$broker1:9092,$broker2:9092"
echo "Kafka brokers: $addresskafka"
cd ../..

# Ollama
echo " Deploying Ollama..."
cd terraform/Ollama-Terraform
terraform init && terraform apply -auto-approve
addressOllama="$(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "Ollama address: $addressOllama"
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

# Deploy BPMN processes to Camunda (after microservices + Kong are up so the address is known)
deploy_bpmn_processes() {
    echo " Waiting for Camunda REST API to be ready (this can take 3-5 min)..."
    until curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
          "http://$addressCamunda:8080" 2>/dev/null | grep -qE "^(200|302|401|404)"; do
        sleep 15
        echo -n "."
    done
    echo ""
    echo " Deploying BPMN processes..."
    for bpmn in BPMN-Processes/*.bpmn; do
        tmpfile="/tmp/$(basename "$bpmn")"
        sed "s|kong-ip|$addressKong|g" "$bpmn" > "$tmpfile"
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -u demo:demo \
            -X POST "http://$addressCamunda:8080/v2/deployments" \
            -F "resources=@$tmpfile")
        echo "  $(basename "$bpmn"): HTTP $http_code"
    done
}

# Group A: Prosumer (8080) + UtilityOperator (8081) + Telemetry (8082)
echo " Deploying Group A (Prosumer, UtilityOperator, Telemetry)..."
cd terraform/Quarkus-Terraform/group-a
cat > terraform.tfvars << EOF
rds_address             = "$addressDB"
docker_image_user       = "$DockerUsername"
docker_image_pull_token = "$DockerPassword"
kafka_brokers           = "$addresskafka"
EOF
terraform init && terraform apply -auto-approve
GROUP_A_ADDRESS="$(terraform state show aws_instance.exampleDeployQuarkus | grep ' public_dns' | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "Group A address: $GROUP_A_ADDRESS"
cd ../../..

# Group B: AssetLink (8080) + FlexibilityEvent (8081)
echo " Deploying Group B (AssetLink, FlexibilityEvent)..."
cd terraform/Quarkus-Terraform/group-b
cat > terraform.tfvars << EOF
rds_address             = "$addressDB"
docker_image_user       = "$DockerUsername"
docker_image_pull_token = "$DockerPassword"
kafka_brokers           = "$addresskafka"
telemetry_url           = "http://$GROUP_A_ADDRESS:8082"
EOF
terraform init && terraform apply -auto-approve
GROUP_B_ADDRESS="$(terraform state show aws_instance.exampleDeployQuarkus | grep ' public_dns' | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "Group B address: $GROUP_B_ADDRESS"
cd ../../..

# Group C: EnergyAnalytics (8080) + GridBalancing (8081)
echo " Deploying Group C (EnergyAnalytics, GridBalancing)..."
cd terraform/Quarkus-Terraform/group-c
cat > terraform.tfvars << EOF
rds_address             = "$addressDB"
docker_image_user       = "$DockerUsername"
docker_image_pull_token = "$DockerPassword"
kafka_brokers           = "$addresskafka"
telemetry_url           = "http://$GROUP_A_ADDRESS:8082"
utilityoperator_url     = "http://$GROUP_A_ADDRESS:8081"
assetlink_url           = "http://$GROUP_B_ADDRESS:8080"
EOF
terraform init && terraform apply -auto-approve
GROUP_C_ADDRESS="$(terraform state show aws_instance.exampleDeployQuarkus | grep ' public_dns' | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "Group C address: $GROUP_C_ADDRESS"
cd ../../..

# FlexibilityForecasting (on Ollama EC2)
echo " Deploying FlexibilityForecasting on Ollama EC2..."
cd terraform/Ollama-Terraform
sed -i "/sudo docker login/d" creation.sh
sed -i "/sudo docker pull.*flexibilityforecasting/d" creation.sh
sed -i "/sudo docker run.*flexibilityforecasting/d" creation.sh
echo "sudo docker login -u \"$DockerUsername\" -p \"$DockerPassword\"" >> creation.sh
echo "sudo docker pull $DockerUsername/flexibilityforecasting:1.0.0-SNAPSHOT" >> creation.sh
echo "sudo docker run -d --name flexibilityforecasting --network=host -e FLEXIBILITYEVENT_SERVICE_URL=\"http://$GROUP_B_ADDRESS:8081\" $DockerUsername/flexibilityforecasting:1.0.0-SNAPSHOT" >> creation.sh
terraform apply -replace="aws_instance.ollamaInstance" -auto-approve
addressOllama="$(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
echo "FlexibilityForecasting: http://$addressOllama:8080"
cd ../..

# Configure Kong Routes
echo " Waiting for Kong to be ready..."
until curl -s -f -o /dev/null --max-time 5 "http://$addressKong:8001"; do
    sleep 5
    echo -n "."
done
echo " Kong is ready!"

# Konga starts automatically via Kong EC2 deploy.sh (no extra instance needed)

export KONG_ADMIN_URL="http://$addressKong:8001"
export PROSUMER_URL="http://$GROUP_A_ADDRESS:8080"
export UTILITY_URL="http://$GROUP_A_ADDRESS:8081"
export TELEMETRY_URL="http://$GROUP_A_ADDRESS:8082"
export ASSETLINK_URL="http://$GROUP_B_ADDRESS:8080"
export FLEXIBILITY_URL="http://$GROUP_B_ADDRESS:8081"
export ENERGYANALYTICS_URL="http://$GROUP_C_ADDRESS:8080"
export GRIDBALANCING_URL="http://$GROUP_C_ADDRESS:8081"
export FORECASTING_URL="http://$addressOllama:8080"
cd terraform/KongTerraform
./configure_routes.sh
cd ../..

# Deploy BPMN processes now that Kong address is confirmed
deploy_bpmn_processes

# Summary
echo ""
echo "================================================"
echo " SPRINT 2 DEPLOYMENT COMPLETE"
echo "================================================"
echo ""

cd terraform/RDS-Terraform
echo "RDS:                $(terraform state show aws_db_instance.example | grep ' address' | sed "s/address//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):3306"
cd ../..

cd terraform/Kafka
for i in 0 1 2; do
    kb="$(terraform state show "aws_instance.exampleKafkaConfiguration[$i]" | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g")"
    echo "Kafka broker $i:     $kb:9092"
done
cd ../..

echo ""
echo "Group A (Prosumer:8080, UtilityOperator:8081, Telemetry:8082):"
echo "  http://$GROUP_A_ADDRESS:8080/q/swagger-ui/  (Prosumer)"
echo "  http://$GROUP_A_ADDRESS:8081/q/swagger-ui/  (UtilityOperator)"
echo "  http://$GROUP_A_ADDRESS:8082/q/swagger-ui/  (Telemetry)"
echo ""
echo "Group B (AssetLink:8080, FlexibilityEvent:8081):"
echo "  http://$GROUP_B_ADDRESS:8080/q/swagger-ui/  (AssetLink)"
echo "  http://$GROUP_B_ADDRESS:8081/q/swagger-ui/  (FlexibilityEvent)"
echo ""
echo "Group C (EnergyAnalytics:8080, GridBalancing:8081):"
echo "  http://$GROUP_C_ADDRESS:8080/q/swagger-ui/  (EnergyAnalytics)"
echo "  http://$GROUP_C_ADDRESS:8081/q/swagger-ui/  (GridBalancing)"
echo ""

cd terraform/Ollama-Terraform
echo "Ollama:             http://$(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):11434"
echo "FlexibilityForecasting: http://$(terraform state show aws_instance.ollamaInstance | grep public_dns | sed "s/public_dns//g;s/=//g;s/\"//g;s/ //g;s/$esc\[[0-9;]*m//g"):8080/q/swagger-ui/"
cd ../..

cd terraform/KongTerraform
echo "Kong Admin:         http://$(terraform state show aws_instance.exampleInstallKong | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):8001"
echo "Kong Gateway:       http://$(terraform state show aws_instance.exampleInstallKong | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):8000"
echo "Konga UI:           http://$(terraform state show aws_instance.exampleInstallKong | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):1337"
cd ../..

cd terraform/Camunda-Terraform
echo "Camunda Operate:    http://$(terraform state show aws_instance.exampleInstallCamundaEngine | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):8081"
echo "Camunda Tasklist:   http://$(terraform state show aws_instance.exampleInstallCamundaEngine | grep public_dns | sed 's/public_dns//g;s/=//g;s/"//g;s/ //g;s/'"$esc"'\[[0-9;]*m//g'):8082"
cd ../..

