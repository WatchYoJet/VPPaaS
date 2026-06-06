#!/bin/bash
set -e

source access.sh

echo "Logging into Docker Hub..."
docker login -u "$DockerUsername" -p "$DockerPassword"

SERVICES=(
  Prosumer
  UtilityOperator
  Telemetry
  AssetLink
  FlexibilityEvent
  EnergyAnalytics
  GridBalancing
  FlexibilityForecasting
)

for svc in "${SERVICES[@]}"; do
  echo ""
  echo "=== Building $svc ==="
  cd microservices/$svc
  ./mvnw package -Dquarkus.profile=prod -DskipTests
  cd ../..
  echo "$svc pushed."
done

echo ""
echo "=== All images built and pushed to Docker Hub ==="
echo "Next: ./CreateAMI.sh (if not done yet) then ./Deploy.sh"
