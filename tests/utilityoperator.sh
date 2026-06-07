#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$KONG_DNS:8000/UtilityOperator"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all utility operators: $response"

response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"name":"EnergyGridTest","location":"Coimbra"}')
echo "POST utility operator: $response"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | tail -1)
echo "Retrieved new operator ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET utility operator by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: operator not found by ID"; exit 1; }

response=$(curl -s -X PUT "$API_URL/$id/EnergyGridTestUpdated/Braga" -H 'accept: application/json')
echo "PUT update utility operator: $response"

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET utility operator after update: $response"
echo "$response" | grep -q '"name":"EnergyGridTestUpdated"' || { echo "Test failed: update not applied"; exit 1; }

response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE utility operator: $response"

echo "All tests passed successfully!"
