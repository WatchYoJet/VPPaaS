find . -type d -name ".terraform" -exec rm -rf '{}' +

for svc in Telemetry Prosumer AssetLink UtilityOperator FlexibilityEvent EnergyAnalytics GridBalancing FlexibilityForecasting; do
    cd microservices/$svc
    mvn clean
    cd ../..
done
