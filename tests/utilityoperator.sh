#!/bin/bash

API_URL='http://ec2-54-237-178-34.compute-1.amazonaws.com:8080/UtilityOperator'

# Note: 4 utility operators are seeded on startup, list will not be empty

# Step 1: GET current list
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all utility operators: $response"

# Step 2: Create a new utility operator
response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"name":"EnergyGridTest","location":"Coimbra"}')
echo "POST utility operator: $response"

# Step 3: GET all and extract the new operator ID (last one)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all utility operators after POST: $response"
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | tail -1)
echo "Retrieved new operator ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

# Step 4: GET by ID
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET utility operator by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: operator not found by ID"; exit 1; }

# Step 5: Update utility operator (name/location as path params)
response=$(curl -s -X PUT "$API_URL/$id/EnergyGridTestUpdated/Braga" \
  -H 'accept: application/json')
echo "PUT update utility operator: $response"

# Step 6: GET by ID to verify update
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET utility operator after update: $response"
echo "$response" | grep -q '"name":"EnergyGridTestUpdated"' || { echo "Test failed: update not applied"; exit 1; }

# Step 7: Delete utility operator
response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE utility operator: $response"

echo "All tests passed successfully!"
