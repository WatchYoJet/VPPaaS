#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$ENERGYANALYTICS_DNS:8080/EnergyAnalytics"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all energy analytics: $response"

response=$(curl -s -X POST "$API_URL/compute" -H 'accept: application/json')
echo "POST /compute: $response"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all energy analytics after compute: $response"
[ "$response" = "[]" ] && { echo "No analytics generated — ensure telemetry data exists first"; exit 1; }

echo "All tests passed successfully!"
