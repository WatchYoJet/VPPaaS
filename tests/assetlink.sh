#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$KONG_DNS:8000/AssetLink"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all asset links: $response"

response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"idProsumer":1,"idUtilityOperator":1}')
echo "POST asset link: $response"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | tail -1)
echo "Retrieved ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET asset link by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: asset link not found by ID"; exit 1; }

response=$(curl -s -X GET "$API_URL/1/1" -H 'accept: application/json')
echo "GET asset link by prosumer+operator IDs: $response"
echo "$response" | grep -q '"idProsumer":1' || { echo "Test failed: lookup by dual ID failed"; exit 1; }

response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE asset link: $response"

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET deleted asset link (expect 404): $response"
echo "$response" | grep -q "\"id\":$id" && { echo "Test failed: asset link still exists after delete"; exit 1; }

echo "All tests passed successfully!"
