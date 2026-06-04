#!/bin/bash

echo "=================================================="
echo "    Kong API Gateway Configuration Script         "
echo "=================================================="

# 1. Definir os URLs (O utilizador pode mudar isto ou exportar como variáveis de ambiente)
KONG_ADMIN_URL=${KONG_ADMIN_URL:-"http://localhost:8001"}

# Substituir <IP> pelos IPs reais gerados pelo Terraform
PROSUMER_URL=${PROSUMER_URL:-"http://<PROSUMER_IP>:8080"}
UTILITY_URL=${UTILITY_URL:-"http://<UTILITY_IP>:8080"}
ASSETLINK_URL=${ASSETLINK_URL:-"http://<ASSETLINK_IP>:8080"}
TELEMETRY_URL=${TELEMETRY_URL:-"http://<TELEMETRY_IP>:8080"}
FLEXIBILITY_URL=${FLEXIBILITY_URL:-"http://<FLEXIBILITY_IP>:8080"}
GRIDBALANCING_URL=${GRIDBALANCING_URL:-"http://<GRIDBALANCING_IP>:8080"}
ENERGYANALYTICS_URL=${ENERGYANALYTICS_URL:-"http://<ENERGYANALYTICS_IP>:8080"}
FORECASTING_URL=${FORECASTING_URL:-"http://<FORECASTING_IP>:8080"}

echo "Using Kong Admin API at: $KONG_ADMIN_URL"
echo "--------------------------------------------------"

# Função auxiliar para criar Service e Route de forma idempotente
create_service_and_route() {
  SERVICE_NAME=$1
  TARGET_URL=$2
  ROUTE_PATH=$3

  echo -n "Configuring $SERVICE_NAME ($ROUTE_PATH -> $TARGET_URL)... "
  
  # Apagar se já existir (útil se o script for corrido várias vezes)
  curl --max-time 10 -s -X DELETE "$KONG_ADMIN_URL/services/$SERVICE_NAME/routes/${SERVICE_NAME}-route" > /dev/null
  curl --max-time 10 -s -X DELETE "$KONG_ADMIN_URL/services/$SERVICE_NAME" > /dev/null

  # 1. Criar Service
  HTTP_CODE=$(curl --max-time 10 -s -o /dev/null -w "%{http_code}" -X POST "$KONG_ADMIN_URL/services" \
    --data name="$SERVICE_NAME" \
    --data url="$TARGET_URL")

  if [ "$HTTP_CODE" -ne 201 ]; then
      echo "Error creating Service"
      return
  fi

  # 2. Criar Route
  HTTP_CODE=$(curl --max-time 10 -s -o /dev/null -w "%{http_code}" -X POST "$KONG_ADMIN_URL/services/$SERVICE_NAME/routes" \
    --data name="${SERVICE_NAME}-route" \
    --data paths[]="$ROUTE_PATH" \
    --data strip_path=false)
    
  if [ "$HTTP_CODE" -ne 201 ]; then
      echo "Error creating Route"
  else
      echo "OK"
  fi
}

# Configurar todos os 8 Microserviços
create_service_and_route "prosumer-service"             "$PROSUMER_URL"        "/Prosumer"
create_service_and_route "utilityoperator-service"      "$UTILITY_URL"         "/UtilityOperator"
create_service_and_route "assetlink-service"            "$ASSETLINK_URL"       "/AssetLink"
create_service_and_route "telemetry-service"            "$TELEMETRY_URL"       "/Telemetry"
create_service_and_route "flexibilityevent-service"     "$FLEXIBILITY_URL"     "/FlexibilityEvent"
create_service_and_route "gridbalancing-service"        "$GRIDBALANCING_URL"   "/GridBalancing"
create_service_and_route "energyanalytics-service"      "$ENERGYANALYTICS_URL" "/EnergyAnalytics"
create_service_and_route "flexibilityforecasting-service" "$FORECASTING_URL"   "/FlexibilityForecasting"

echo "--------------------------------------------------"
echo "Done! The API Gateway is now configured."
echo "BPMN Processes can now call: http://<kong-ip>:8000/<route>"
