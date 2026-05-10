#!/bin/bash

API_URL='http://ec2-54-174-239-157.compute-1.amazonaws.com:8080/AssetLink'

# Note: Requires prosumer ID=1 and utility operator ID=1 to exist (seeded on startup)

# Step 1: GET current list (may already have data)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all asset links: $response"

# Step 2: Create a new asset link
# Side effect: creates Kafka topic '1-ArcoCegoLisbon' and registers Telemetry consumer
response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"idProsumer":1,"idUtilityOperator":1}')
echo "POST asset link: $response"

# Step 3: GET all and extract the new ID (last one)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all asset links after POST: $response"
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | tail -1)
echo "Retrieved ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

# Step 4: GET by ID
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET asset link by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: asset link not found by ID"; exit 1; }

# Step 5: GET by prosumer + operator ID pair
response=$(curl -s -X GET "$API_URL/1/1" -H 'accept: application/json')
echo "GET asset link by prosumer+operator IDs: $response"
echo "$response" | grep -q '"idProsumer":1' || { echo "Test failed: lookup by dual ID failed"; exit 1; }

# Step 6: Delete the asset link we created
response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE asset link: $response"

# Step 7: Confirm it is gone
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET deleted asset link (expect 404): $response"
echo "$response" | grep -q "\"id\":$id" && { echo "Test failed: asset link still exists after delete"; exit 1; }

echo "All tests passed successfully!"
