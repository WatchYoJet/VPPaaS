#!/bin/bash

API_URL='http://<PROSUMER_EC2>:8080/Prosumer'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all prosumers: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Create a new prosumer
response=$(curl -s -X POST "$API_URL" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"name":"SolarHome","FiscalNumber":123456789,"location":"Lisbon"}')
echo "POST prosumer: $response"

# Step 3: GET all and extract ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all prosumers after POST: $response"
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
echo "Retrieved ID: $id"
[ -z "$id" ] && { echo "Test failed: no ID found"; exit 1; }

# Step 4: GET by ID
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET prosumer by ID: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: prosumer not found by ID"; exit 1; }

# Step 5: Update prosumer (name/FiscalNumber/location as path params)
response=$(curl -s -X PUT "$API_URL/$id/SolarHomeUpdated/987654321/Porto" \
  -H 'accept: application/json')
echo "PUT update prosumer: $response"

# Step 6: GET by ID to verify update
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET prosumer after update: $response"
echo "$response" | grep -q '"name":"SolarHomeUpdated"' || { echo "Test failed: update not applied"; exit 1; }

# Step 7: Delete prosumer
response=$(curl -s -X DELETE "$API_URL/$id" -H 'accept: application/json')
echo "DELETE prosumer: $response"

# Step 8: Check empty again
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all after delete: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list after delete"; exit 1; }

echo "All tests passed successfully!"
