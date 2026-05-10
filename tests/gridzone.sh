#!/bin/bash

API_URL='http://ec2-54-237-178-34.compute-1.amazonaws.com:8080/GridZone'

# Step 1: GET all grid zones
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all grid zones: $response"

# Step 2: Create a grid zone under utility operator ID 1
response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"utilityOperatorId":1,"name":"LISBON-DT","maxCapacity":500.0,"boundaries":"POLYGON((0 0,1 0,1 1,0 1,0 0))"}')
echo "POST grid zone: $response"

# Step 3: GET all and extract ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all grid zones after POST: $response"
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
echo "Retrieved ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

# Step 4: GET by ID
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET grid zone by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: grid zone not found by ID"; exit 1; }

# Step 5: GET by operator ID
response=$(curl -s -X GET "$API_URL/operator/1" -H 'accept: application/json')
echo "GET grid zones by operator 1: $response"
echo "$response" | grep -q '"utilityOperatorId":1' || { echo "Test failed: operator filter not working"; exit 1; }

# Step 6: Update maxCapacity and boundaries
# Boundaries must be URL-encoded — spaces break path parameters
BOUNDARIES="POLYGON%28%280%200%2C2%200%2C2%202%2C0%202%2C0%200%29%29"
response=$(curl -s -X PUT "$API_URL/$id/750.0/$BOUNDARIES" \
  -H 'accept: application/json')
echo "PUT update grid zone: $response"

# Step 7: GET by ID to verify update
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET grid zone after update: $response"
echo "$response" | grep -q '"maxCapacity":750.0' || { echo "Test failed: update not applied"; exit 1; }

# Step 8: Delete
response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE grid zone: $response"

# Step 9: Confirm deleted
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET deleted grid zone (expect 404): $response"

echo "All tests passed successfully!"
