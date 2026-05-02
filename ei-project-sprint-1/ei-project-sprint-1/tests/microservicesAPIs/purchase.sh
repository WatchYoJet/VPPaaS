#!/bin/bash

API_URL='http://ec2-3-221-160-179.compute-1.amazonaws.com:8080/Purchase'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all purchases: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Make a POST request to /Purchase/Consume
post_data='{
  "TopicName": "1-continente"
}'
response=$(curl -s -X POST "$API_URL/Consume" -H 'accept: text/plain' -H 'Content-Type: application/json' -d "$post_data")
echo "POST consume response: $response"
[ "$response" = "New worker started" ] || { echo "Test failed: expected response 'New worker started'"; exit 1; }

echo "All tests passed successfully!"
