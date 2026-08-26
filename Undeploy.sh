#!/bin/bash
set -e

if [ ! -f amis.env ]; then
  echo "ERROR: amis.env not found."
  exit 1
fi
source amis.env

# ============================================================
# ACCOUNT 2 - destroy first (depends on Account 1 infra)
# ============================================================
source access2.sh

export TF_VAR_docker_base_ami=$ACCOUNT2_AMI
export TF_VAR_docker_image_user=$DockerUsername
export TF_VAR_docker_image_pull_token=$DockerPassword

echo "=== Destroying Account 2 Services ==="

terraform -chdir=terraform/Account2/GridBalancing init -reconfigure
terraform -chdir=terraform/Account2/GridBalancing destroy -auto-approve

terraform -chdir=terraform/Account2/EnergyAnalytics init -reconfigure
terraform -chdir=terraform/Account2/EnergyAnalytics destroy -auto-approve

terraform -chdir=terraform/Account2/Ollama init -reconfigure
terraform -chdir=terraform/Account2/Ollama destroy -auto-approve

terraform -chdir=terraform/Account2/FlexibilityEvent init -reconfigure
terraform -chdir=terraform/Account2/FlexibilityEvent destroy -auto-approve

terraform -chdir=terraform/Account2/AssetLink init -reconfigure
terraform -chdir=terraform/Account2/AssetLink destroy -auto-approve

terraform -chdir=terraform/Account2/Konga init -reconfigure
terraform -chdir=terraform/Account2/Konga destroy -auto-approve

# ============================================================
# ACCOUNT 1 - microservices first, then infrastructure
# ============================================================
source access.sh

export TF_VAR_docker_base_ami=$ACCOUNT1_AMI
export TF_VAR_docker_image_user=$DockerUsername
export TF_VAR_docker_image_pull_token=$DockerPassword

echo "=== Destroying Account 1 Microservices ==="

terraform -chdir=terraform/Account1/Telemetry init -reconfigure
terraform -chdir=terraform/Account1/Telemetry destroy -auto-approve

terraform -chdir=terraform/Account1/UtilityOperator init -reconfigure
terraform -chdir=terraform/Account1/UtilityOperator destroy -auto-approve

terraform -chdir=terraform/Account1/Prosumer init -reconfigure
terraform -chdir=terraform/Account1/Prosumer destroy -auto-approve

echo "=== Destroying Account 1 Infrastructure ==="

terraform -chdir=terraform/Account1/Camunda init -reconfigure
terraform -chdir=terraform/Account1/Camunda destroy -auto-approve

terraform -chdir=terraform/Account1/Kong init -reconfigure
terraform -chdir=terraform/Account1/Kong destroy -auto-approve

terraform -chdir=terraform/Account1/Kafka init -reconfigure
terraform -chdir=terraform/Account1/Kafka destroy -auto-approve

terraform -chdir=terraform/Account1/RDS init -reconfigure
terraform -chdir=terraform/Account1/RDS destroy -auto-approve

rm -f account1-addresses.env

echo ""
echo "=== Full Teardown Complete ==="
