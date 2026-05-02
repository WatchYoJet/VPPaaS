#!/bin/bash

API_URL='http://ec2-44-213-101-66.compute-1.amazonaws.com:8080/Shop'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all shops: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Create a new shop
post_data='{
  "address": "string",
  "postalCode": "string",
  "name": "string"
}'
response=$(curl -s -X POST "$API_URL" -H 'accept: application/json' -H 'Content-Type: application/json' -d "$post_data")
echo "POST shop response: $response"

# Step 3: GET all shops and get the ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all shops after POST: $response"
shop_id=$(echo "$response" | grep -oP '"id":\s*\K\d+')
echo "Retrieved shop ID: $shop_id"
[ -z "$shop_id" ] && { echo "Test failed: no shop ID found"; exit 1; }

# Step 4: GET shop by ID
response=$(curl -s -X GET "$API_URL/$shop_id" -H 'accept: application/json')
echo "GET shop by ID: $response"
echo "$response" | grep -q "\"id\":$shop_id" || { echo "Test failed: shop not found by ID"; exit 1; }

# Step 5: Update shop by ID (PUT)
put_data='{
  "address": "aaaa",
  "postalCode": "ppppp",
  "name": "nnnnn"
}'
response=$(curl -s -X PUT "$API_URL/$shop_id" -H 'accept: application/json' -H 'Content-Type: application/json' -d "$put_data")
echo "PUT update response: $response"

# Step 6: GET shop by ID again to confirm update
response=$(curl -s -X GET "$API_URL/$shop_id" -H 'accept: application/json')
echo "GET shop by ID after update: $response"
echo "$response" | grep -q '"address":"aaaa"' || { echo "Test failed: update not confirmed (address)"; exit 1; }
echo "$response" | grep -q '"postalCode":"ppppp"' || { echo "Test failed: update not confirmed (postalCode)"; exit 1; }
echo "$response" | grep -q '"name":"nnnnn"' || { echo "Test failed: update not confirmed (name)"; exit 1; }

# Step 7: Delete shop by ID
response=$(curl -s -X DELETE "$API_URL/$shop_id" -H 'accept: application/json')
echo "DELETE shop response: $response"

# Step 8: GET all shops again, expect empty list
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all shops after delete: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list after delete"; exit 1; }

echo "All tests passed successfully!"
