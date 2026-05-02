#!/bin/bash

API_URL='http://ec2-34-201-0-73.compute-1.amazonaws.com:8080/SelledProduct'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all selled products: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Create a new selled product
post_data='{
  "typeOfAnalysis": "CUSTOMER",
  "typeValue": "CUSTOMER",
  "timestamp": "2022-03-10T12:15:50",
  "result": 10
}'
response=$(curl -s -X POST "$API_URL" -H 'accept: application/json' -H 'Content-Type: application/json' -d "$post_data")
echo "POST selled product response: $response"

# Step 3: GET all selled products and get the ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all selled products after POST: $response"
prod_id=$(echo "$response" | grep -oP '"id":\s*\K\d+')
echo "Retrieved selled product ID: $prod_id"
[ -z "$prod_id" ] && { echo "Test failed: no selled product ID found"; exit 1; }

# Step 4: GET selled product by ID
response=$(curl -s -X GET "$API_URL/$prod_id" -H 'accept: application/json')
echo "GET selled product by ID: $response"
echo "$response" | grep -q "\"id\":$prod_id" || { echo "Test failed: selled product not found by ID"; exit 1; }

# Step 5: Delete selled product by ID
response=$(curl -s -X DELETE "$API_URL/$prod_id" -H 'accept: application/json')
echo "DELETE selled product response: $response"

# Step 6: GET all selled products again, expect empty list
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all selled products after delete: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list after delete"; exit 1; }

echo "All tests passed successfully!"