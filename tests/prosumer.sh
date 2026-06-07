#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$KONG_DNS:8000/Prosumer"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all prosumers: $response"

response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"name":"SolarHome","FiscalNumber":123456789,"location":"Lisbon"}')
echo "POST prosumer: $response"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | tail -1)
echo "Retrieved ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET prosumer by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: prosumer not found by ID"; exit 1; }

response=$(curl -s -X PUT "$API_URL/$id/SolarHomeUpdated/987654321/Porto" -H 'accept: application/json')
echo "PUT update prosumer: $response"

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET prosumer after update: $response"
echo "$response" | grep -q '"name":"SolarHomeUpdated"' || { echo "Test failed: update not applied"; exit 1; }

response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE prosumer: $response"

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET deleted prosumer (expect 404): $response"
echo "$response" | grep -q "\"id\":$id" && { echo "Test failed: prosumer still exists after delete"; exit 1; }

echo "All tests passed successfully!"
