#!/bin/bash

API_URL='http://ec2-34-201-5-165.compute-1.amazonaws.com:8080/Loyaltycard'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all loyalty cards: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Create a new loyalty card
post_data='{
  "idCustomer": 1,
  "idShop": 1
}'
response=$(curl -s -X POST "$API_URL" -H 'accept: application/json' -H 'Content-Type: application/json' -d "$post_data")
echo "POST loyalty card response: $response"

# Step 3: GET all loyalty cards and extract ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all loyalty cards after POST: $response"
card_id=$(echo "$response" | grep -oP '"id":\s*\K\d+')
echo "Retrieved loyalty card ID: $card_id"
[ -z "$card_id" ] && { echo "Test failed: no loyalty card ID found"; exit 1; }

# Step 4: GET loyalty card by ID
response=$(curl -s -X GET "$API_URL/$card_id" -H 'accept: application/json')
echo "GET loyalty card by ID: $response"
echo "$response" | grep -q "\"id\":$card_id" || { echo "Test failed: loyalty card not found by ID"; exit 1; }

# Step 5: GET loyalty card by Customer ID and Shop ID
response=$(curl -s -X GET "$API_URL/1/1" -H 'accept: application/json')
echo "GET loyalty card by Customer ID and Shop ID: $response"
echo "$response" | grep -q "\"id\":$card_id" || { echo "Test failed: loyalty card not found by Customer and Shop ID"; exit 1; }

# Step 6: DELETE loyalty card by Customer ID and Shop ID
response=$(curl -s -X DELETE "$API_URL/1/1" -H 'accept: application/json')
echo "DELETE loyalty card by Customer and Shop ID: $response"

# Step 7: POST another loyalty card to test DELETE by ID
response=$(curl -s -X POST "$API_URL" -H 'accept: application/json' -H 'Content-Type: application/json' -d "$post_data")
echo "POST loyalty card response: $response"

# Step 8: GET all loyalty cards and extract new ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all loyalty cards after second POST: $response"
new_card_id=$(echo "$response" | grep -oP '"id":\s*\K\d+')
echo "Retrieved new loyalty card ID: $new_card_id"
[ -z "$new_card_id" ] && { echo "Test failed: no new loyalty card ID found"; exit 1; }

# Step 9: DELETE loyalty card by ID
response=$(curl -s -X DELETE "$API_URL/$new_card_id" -H 'accept: application/json')
echo "DELETE loyalty card by ID: $response"

# Step 10: GET all loyalty cards again, expect empty list
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all loyalty cards after delete: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list after delete"; exit 1; }

echo "All tests passed successfully!"
