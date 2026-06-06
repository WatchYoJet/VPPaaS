#!/bin/bash

# Remove Terraform provider caches (re-downloaded by terraform init)
find . -type d -name ".terraform" -not -path "*/ei-project/*" -exec rm -rf '{}' +

# Remove generated runtime files
rm -f amis.env account1-addresses.env

# Clean Maven build artifacts
for svc in Telemetry Prosumer AssetLink UtilityOperator FlexibilityEvent EnergyAnalytics GridBalancing FlexibilityForecasting; do
    if [ -d "microservices/$svc" ]; then
        cd microservices/$svc
        mvn clean -q
        cd ../..
    fi
done

echo "Clean complete."
