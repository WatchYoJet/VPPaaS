#!/bin/bash
set -e

if [ ! -f amis.env ]; then
  echo "ERROR: amis.env not found. Run ./CreateAMI.sh first."
  exit 1
fi
source amis.env

# ============================================================
# ACCOUNT 1
# ============================================================
source access.sh

export TF_VAR_docker_base_ami=$ACCOUNT1_AMI
export TF_VAR_docker_image_user=$DockerUsername
export TF_VAR_docker_image_pull_token=$DockerPassword

echo "=== Deploying Account 1 Infrastructure ==="

terraform -chdir=terraform/Account1/RDS init -reconfigure
terraform -chdir=terraform/Account1/RDS apply -auto-approve
RDS_ENDPOINT=$(terraform -chdir=terraform/Account1/RDS output -raw address)

terraform -chdir=terraform/Account1/Kafka init -reconfigure

# Auto-import Kafka SG if it exists in AWS but not in Terraform state (prevents InvalidGroup.Duplicate)
KAFKA_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=terraform-kafka-account1" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || true)
if [ -n "$KAFKA_SG_ID" ] && [ "$KAFKA_SG_ID" != "None" ]; then
  echo "Found existing Kafka SG $KAFKA_SG_ID — importing into state..."
  terraform -chdir=terraform/Account1/Kafka import aws_security_group.instance "$KAFKA_SG_ID" 2>/dev/null || true
fi

terraform -chdir=terraform/Account1/Kafka apply -auto-approve
KAFKA_BROKERS=$(terraform -chdir=terraform/Account1/Kafka output -raw kafka_brokers)

FIRST_BROKER_HOST=$(echo "$KAFKA_BROKERS" | cut -d',' -f1 | cut -d':' -f1)
echo -n "Waiting for Kafka brokers to be ready..."
ELAPSED=0
until nc -zw 3 "$FIRST_BROKER_HOST" 9092 2>/dev/null; do
  if [ $ELAPSED -ge 300 ]; then
    echo ""
    echo "Kafka not ready after 5 minutes — re-provisioning cluster setup..."
    terraform -chdir=terraform/Account1/Kafka apply -auto-approve \
      -replace='null_resource.kafkaClusterSetup[0]' \
      -replace='null_resource.kafkaClusterSetup[1]' \
      -replace='null_resource.kafkaClusterSetup[2]'
    KAFKA_BROKERS=$(terraform -chdir=terraform/Account1/Kafka output -raw kafka_brokers)
    FIRST_BROKER_HOST=$(echo "$KAFKA_BROKERS" | cut -d',' -f1 | cut -d':' -f1)
    ELAPSED=0
    echo -n "Waiting for Kafka brokers (retry)..."
  fi
  echo -n "."
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done
echo " ready! (${ELAPSED}s)"

terraform -chdir=terraform/Account1/Kong init -reconfigure
terraform -chdir=terraform/Account1/Kong apply -auto-approve
KONG_DNS=$(terraform -chdir=terraform/Account1/Kong output -raw public_dns)

terraform -chdir=terraform/Account1/Camunda init -reconfigure
terraform -chdir=terraform/Account1/Camunda apply -auto-approve
CAMUNDA_DNS=$(terraform -chdir=terraform/Account1/Camunda output -raw public_dns)

echo "=== Deploying Account 1 Microservices ==="

sed -i "s|rds_address.*=.*|rds_address = \"$RDS_ENDPOINT\"|" terraform/Account1/Prosumer/terraform.tfvars
terraform -chdir=terraform/Account1/Prosumer init -reconfigure
terraform -chdir=terraform/Account1/Prosumer apply -auto-approve
PROSUMER_DNS=$(terraform -chdir=terraform/Account1/Prosumer output -raw public_dns)

sed -i "s|rds_address.*=.*|rds_address = \"$RDS_ENDPOINT\"|" terraform/Account1/UtilityOperator/terraform.tfvars
terraform -chdir=terraform/Account1/UtilityOperator init -reconfigure
terraform -chdir=terraform/Account1/UtilityOperator apply -auto-approve
UTILITYOPERATOR_DNS=$(terraform -chdir=terraform/Account1/UtilityOperator output -raw public_dns)

sed -i "s|rds_address.*=.*|rds_address = \"$RDS_ENDPOINT\"|" terraform/Account1/Telemetry/terraform.tfvars
sed -i "s|kafka_brokers.*=.*|kafka_brokers = \"$KAFKA_BROKERS\"|" terraform/Account1/Telemetry/terraform.tfvars
terraform -chdir=terraform/Account1/Telemetry init -reconfigure
terraform -chdir=terraform/Account1/Telemetry apply -auto-approve
TELEMETRY_DNS=$(terraform -chdir=terraform/Account1/Telemetry output -raw public_dns)

echo ""
echo "Account 1 complete. Saving addresses..."
cat > account1-addresses.env <<EOF
RDS_ENDPOINT=$RDS_ENDPOINT
KAFKA_BROKERS=$KAFKA_BROKERS
KONG_DNS=$KONG_DNS
CAMUNDA_DNS=$CAMUNDA_DNS
PROSUMER_DNS=$PROSUMER_DNS
UTILITYOPERATOR_DNS=$UTILITYOPERATOR_DNS
TELEMETRY_DNS=$TELEMETRY_DNS
EOF

# ============================================================
# ACCOUNT 2
# ============================================================
source access2.sh

export TF_VAR_docker_base_ami=$ACCOUNT2_AMI
export TF_VAR_docker_image_user=$DockerUsername
export TF_VAR_docker_image_pull_token=$DockerPassword

echo "=== Deploying Account 2 Services ==="

sed -i "s|kong_admin_url.*=.*|kong_admin_url = \"http://$KONG_DNS:8001\"|" terraform/Account2/Konga/terraform.tfvars
terraform -chdir=terraform/Account2/Konga init -reconfigure
terraform -chdir=terraform/Account2/Konga apply -auto-approve
KONGA_DNS=$(terraform -chdir=terraform/Account2/Konga output -raw public_dns)

sed -i "s|rds_address.*=.*|rds_address = \"$RDS_ENDPOINT\"|" terraform/Account2/AssetLink/terraform.tfvars
sed -i "s|kafka_brokers.*=.*|kafka_brokers = \"$KAFKA_BROKERS\"|" terraform/Account2/AssetLink/terraform.tfvars
sed -i "s|telemetry_url.*=.*|telemetry_url = \"http://$TELEMETRY_DNS:8080\"|" terraform/Account2/AssetLink/terraform.tfvars
terraform -chdir=terraform/Account2/AssetLink init -reconfigure
terraform -chdir=terraform/Account2/AssetLink apply -auto-approve
ASSETLINK_DNS=$(terraform -chdir=terraform/Account2/AssetLink output -raw public_dns)

sed -i "s|rds_address.*=.*|rds_address = \"$RDS_ENDPOINT\"|" terraform/Account2/FlexibilityEvent/terraform.tfvars
sed -i "s|kafka_brokers.*=.*|kafka_brokers = \"$KAFKA_BROKERS\"|" terraform/Account2/FlexibilityEvent/terraform.tfvars
sed -i "s|telemetry_url.*=.*|telemetry_url = \"http://$TELEMETRY_DNS:8080\"|" terraform/Account2/FlexibilityEvent/terraform.tfvars
terraform -chdir=terraform/Account2/FlexibilityEvent init -reconfigure
terraform -chdir=terraform/Account2/FlexibilityEvent apply -auto-approve
FLEXIBILITYEVENT_DNS=$(terraform -chdir=terraform/Account2/FlexibilityEvent output -raw public_dns)

sed -i "s|flexibilityevent_url.*=.*|flexibilityevent_url = \"http://$FLEXIBILITYEVENT_DNS:8080\"|" terraform/Account2/Ollama/terraform.tfvars
terraform -chdir=terraform/Account2/Ollama init -reconfigure
terraform -chdir=terraform/Account2/Ollama apply -auto-approve
OLLAMA_DNS=$(terraform -chdir=terraform/Account2/Ollama output -raw public_dns)

sed -i "s|rds_address.*=.*|rds_address = \"$RDS_ENDPOINT\"|" terraform/Account2/EnergyAnalytics/terraform.tfvars
sed -i "s|kafka_brokers.*=.*|kafka_brokers = \"$KAFKA_BROKERS\"|" terraform/Account2/EnergyAnalytics/terraform.tfvars
sed -i "s|telemetry_url.*=.*|telemetry_url = \"http://$TELEMETRY_DNS:8080\"|" terraform/Account2/EnergyAnalytics/terraform.tfvars
terraform -chdir=terraform/Account2/EnergyAnalytics init -reconfigure
terraform -chdir=terraform/Account2/EnergyAnalytics apply -auto-approve
ENERGYANALYTICS_DNS=$(terraform -chdir=terraform/Account2/EnergyAnalytics output -raw public_dns)

sed -i "s|rds_address.*=.*|rds_address = \"$RDS_ENDPOINT\"|" terraform/Account2/GridBalancing/terraform.tfvars
sed -i "s|kafka_brokers.*=.*|kafka_brokers = \"$KAFKA_BROKERS\"|" terraform/Account2/GridBalancing/terraform.tfvars
sed -i "s|telemetry_url.*=.*|telemetry_url = \"http://$TELEMETRY_DNS:8080\"|" terraform/Account2/GridBalancing/terraform.tfvars
sed -i "s|utilityoperator_url.*=.*|utilityoperator_url = \"http://$UTILITYOPERATOR_DNS:8080\"|" terraform/Account2/GridBalancing/terraform.tfvars
sed -i "s|assetlink_url.*=.*|assetlink_url = \"http://$ASSETLINK_DNS:8080\"|" terraform/Account2/GridBalancing/terraform.tfvars
terraform -chdir=terraform/Account2/GridBalancing init -reconfigure
terraform -chdir=terraform/Account2/GridBalancing apply -auto-approve
GRIDBALANCING_DNS=$(terraform -chdir=terraform/Account2/GridBalancing output -raw public_dns)

cat >> account1-addresses.env <<EOF
KONGA_DNS=$KONGA_DNS
ASSETLINK_DNS=$ASSETLINK_DNS
FLEXIBILITYEVENT_DNS=$FLEXIBILITYEVENT_DNS
OLLAMA_DNS=$OLLAMA_DNS
ENERGYANALYTICS_DNS=$ENERGYANALYTICS_DNS
GRIDBALANCING_DNS=$GRIDBALANCING_DNS
EOF

echo ""
echo "=== Configuring Kong Routes ==="

KONG_ADMIN_URL="http://$KONG_DNS:8001"
echo -n "Waiting for Kong Admin API..."
until curl -s --max-time 5 "$KONG_ADMIN_URL" > /dev/null 2>&1; do
  echo -n "."
  sleep 10
done
echo " ready!"

configure_kong_route() {
  local name=$1 url=$2 path=$3
  curl --max-time 10 -s -X DELETE "$KONG_ADMIN_URL/services/$name/routes/${name}-route" > /dev/null
  curl --max-time 10 -s -X DELETE "$KONG_ADMIN_URL/services/$name" > /dev/null
  local code
  code=$(curl --max-time 10 -s -o /dev/null -w "%{http_code}" -X POST "$KONG_ADMIN_URL/services" \
    --data name="$name" --data url="$url")
  [ "$code" -ne 201 ] && { echo "  ERROR creating service $name (HTTP $code)"; return; }
  code=$(curl --max-time 10 -s -o /dev/null -w "%{http_code}" -X POST "$KONG_ADMIN_URL/services/$name/routes" \
    --data name="${name}-route" --data "paths[]=$path" --data strip_path=false)
  [ "$code" -eq 201 ] && echo "  $path -> $url" || echo "  ERROR creating route for $name (HTTP $code)"
}

configure_kong_route "prosumer-service"               "http://$PROSUMER_DNS:8080"        "/Prosumer"
configure_kong_route "utilityoperator-service"        "http://$UTILITYOPERATOR_DNS:8080" "/UtilityOperator"
configure_kong_route "gridzone-service"               "http://$UTILITYOPERATOR_DNS:8080" "/GridZone"
configure_kong_route "assetlink-service"              "http://$ASSETLINK_DNS:8080"       "/AssetLink"
configure_kong_route "telemetry-service"              "http://$TELEMETRY_DNS:8080"       "/Telemetry"
configure_kong_route "flexibilityevent-service"       "http://$FLEXIBILITYEVENT_DNS:8080" "/FlexibilityEvent"
configure_kong_route "gridbalancing-service"          "http://$GRIDBALANCING_DNS:8080"   "/GridBalancing"
configure_kong_route "energyanalytics-service"        "http://$ENERGYANALYTICS_DNS:8080" "/EnergyAnalytics"
configure_kong_route "flexibilityforecasting-service" "http://$OLLAMA_DNS:8080"          "/FlexibilityForecasting"

echo ""
echo "=== Full Deployment Complete ==="
echo ""
echo "Account 1:"
echo "  Prosumer:        http://$PROSUMER_DNS:8080"
echo "  UtilityOperator: http://$UTILITYOPERATOR_DNS:8080"
echo "  Telemetry:       http://$TELEMETRY_DNS:8080"
echo "  Kong (proxy):    http://$KONG_DNS:8000"
echo "  Kong (admin):    http://$KONG_DNS:8002"
echo "  Camunda:         http://$CAMUNDA_DNS:8080"
echo "  RDS:             $RDS_ENDPOINT"
echo "  Kafka:           $KAFKA_BROKERS"
echo ""
echo "Account 2:"
echo "  Konga:                  http://$KONGA_DNS:1337"
echo "  Ollama:                 http://$OLLAMA_DNS:11434"
echo "  FlexibilityForecasting: http://$OLLAMA_DNS:8080"
echo "  AssetLink:              http://$ASSETLINK_DNS:8080"
echo "  FlexibilityEvent:       http://$FLEXIBILITYEVENT_DNS:8080"
echo "  EnergyAnalytics:        http://$ENERGYANALYTICS_DNS:8080"
echo "  GridBalancing:          http://$GRIDBALANCING_DNS:8080"
