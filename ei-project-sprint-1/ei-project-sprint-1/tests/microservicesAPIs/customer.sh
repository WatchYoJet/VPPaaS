#!/bin/bash

API_URL='http://ec2-54-237-188-57.compute-1.amazonaws.com:8080/Customer'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all customers: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Create a new customer
post_data='{
  "FiscalNumber": 0,
  "address": "string",
  "postalCode": "string",
  "name": "string"
}'
response=$(curl -s -X POST "$API_URL" -H 'accept: application/json' -H 'Content-Type: application/json' -d "$post_data")
echo "POST customer response: $response"

# Step 3: GET all customers and get the ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all customers after POST: $response"
cust_id=$(echo "$response" | grep -oP '"id":\s*\K\d+')
echo "Retrieved customer ID: $cust_id"
[ -z "$cust_id" ] && { echo "Test failed: no customer ID found"; exit 1; }

# Step 4: GET customer by ID
response=$(curl -s -X GET "$API_URL/$cust_id" -H 'accept: application/json')
echo "GET customer by ID: $response"
echo "$response" | grep -q "\"id\":$cust_id" || { echo "Test failed: customer not found by ID"; exit 1; }

# Step 5: Update customer by ID (PUT)
put_data='{
  "FiscalNumber": 1,
  "address": "aaaaaa",
  "postalCode": "ppppp",
  "name": "nnnnn"
}'
response=$(curl -s -X PUT "$API_URL/$cust_id" -H 'accept: application/json' -H 'Content-Type: application/json' -d "$put_data")
echo "PUT update response: $response"

# Step 6: GET customer by ID again to confirm update
response=$(curl -s -X GET "$API_URL/$cust_id" -H 'accept: application/json')
echo "GET customer by ID after update: $response"
echo "$response" | grep -q '"address":"aaaaaa"' || { echo "Test failed: update not confirmed (address)"; exit 1; }
echo "$response" | grep -q '"postalCode":"ppppp"' || { echo "Test failed: update not confirmed (postalCode)"; exit 1; }
echo "$response" | grep -q '"name":"nnnnn"' || { echo "Test failed: update not confirmed (name)"; exit 1; }
echo "$response" | grep -q '"FiscalNumber":1' || { echo "Test failed: update not confirmed (FiscalNumber)"; exit 1; }

# Step 7: Delete customer by ID
response=$(curl -s -X DELETE "$API_URL/$cust_id" -H 'accept: application/json')
echo "DELETE customer response: $response"

# Step 8: GET all customers again, expect empty list
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all customers after delete: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list after delete"; exit 1; }

echo "All tests passed successfully!"
