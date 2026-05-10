#!/bin/bash

API_URL='http://ec2-98-93-200-158.compute-1.amazonaws.com:8080/Prosumer'

# Step 1: GET current list (may already have data)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all prosumers: $response"

# Step 2: Create a new prosumer
response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"name":"SolarHome","FiscalNumber":123456789,"location":"Lisbon"}')
echo "POST prosumer: $response"

# Step 3: GET all and extract the new ID (last one added)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all prosumers after POST: $response"
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | tail -1)
echo "Retrieved ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

# Step 4: GET by ID
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET prosumer by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: prosumer not found by ID"; exit 1; }

# Step 5: Update prosumer
response=$(curl -s -X PUT "$API_URL/$id/SolarHomeUpdated/987654321/Porto" \
  -H 'accept: application/json')
echo "PUT update prosumer: $response"

# Step 6: GET by ID to verify update
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET prosumer after update: $response"
echo "$response" | grep -q '"name":"SolarHomeUpdated"' || { echo "Test failed: update not applied"; exit 1; }

# Step 7: Delete the prosumer we created
response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE prosumer: $response"

# Step 8: Confirm it is gone
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET deleted prosumer (expect 404): $response"
echo "$response" | grep -q "\"id\":$id" && { echo "Test failed: prosumer still exists after delete"; exit 1; }

echo "All tests passed successfully!"
