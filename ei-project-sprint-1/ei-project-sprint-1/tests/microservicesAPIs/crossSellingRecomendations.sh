#!/bin/bash

API_URL='http://ec2-3-239-198-232.compute-1.amazonaws.com:8080/CrossSellingRecommendation'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json' | tr -d '%')
echo "GET all recommendations: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Create a cross-selling recommendation
response=$(curl -s -X POST "$API_URL" -H 'accept: application/json' -H 'Content-Type: application/json' -d '{"idLoyaltyCard": 0, "idsShops": [1,2,3]}')
echo "POST recommendation response: $response"

# Step 3: Check if the recommendation was created and get ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all recommendations: $response"
rec_id=$(echo "$response" | grep -oP '"id":\s*\K\d+')
echo "Retrieved recommendation ID from GET all: $rec_id"
[ -z "$rec_id" ] && { echo "Test failed: could not retrieve recommendation ID"; exit 1; }

# Step 4: Get recommendation by ID
response=$(curl -s -X GET "$API_URL/$rec_id" -H 'accept: application/json')
echo "GET recommendation by ID: $response"
echo "$response" | grep -q "\"id\":$rec_id" || { echo "Test failed: recommendation not found by ID"; exit 1; }

# Step 5: Delete the recommendation
response=$(curl -s -X DELETE "$API_URL/$rec_id" -H 'accept: application/json')
echo "DELETE recommendation $rec_id: $response"

# Step 6: Check if the list is empty again
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json' | tr -d '%')
echo "GET all recommendations after delete: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list after delete"; exit 1; }

echo "All tests passed successfully!"