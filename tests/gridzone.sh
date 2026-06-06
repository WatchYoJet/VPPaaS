#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$UTILITYOPERATOR_DNS:8080/GridZone"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all grid zones: $response"

response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"utilityOperatorId":1,"name":"LISBON-DT","maxCapacity":500.0,"boundaries":"POLYGON((0 0,1 0,1 1,0 1,0 0))"}')
echo "POST grid zone: $response"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
echo "Retrieved ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET grid zone by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: grid zone not found by ID"; exit 1; }

response=$(curl -s -X GET "$API_URL/operator/1" -H 'accept: application/json')
echo "GET grid zones by operator 1: $response"
echo "$response" | grep -q '"utilityOperatorId":1' || { echo "Test failed: operator filter not working"; exit 1; }

BOUNDARIES="POLYGON%28%280%200%2C2%200%2C2%202%2C0%202%2C0%200%29%29"
response=$(curl -s -X PUT "$API_URL/$id/750.0/$BOUNDARIES" -H 'accept: application/json')
echo "PUT update grid zone: $response"

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET grid zone after update: $response"
echo "$response" | grep -q '"maxCapacity":750.0' || { echo "Test failed: update not applied"; exit 1; }

response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE grid zone: $response"

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET deleted grid zone (expect 404): $response"

echo "All tests passed successfully!"
