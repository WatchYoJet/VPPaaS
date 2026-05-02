#!/bin/bash

API_URL='http://ec2-3-236-134-215.compute-1.amazonaws.com:8080/DiscountCoupon'

# Step 1: Check if the list is empty
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json' | tr -d '%')
echo "GET all coupons: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list"; exit 1; }

# Step 2: Create a discount coupon
response=$(curl -s -X POST "$API_URL" -H 'accept: application/json' -H 'Content-Type: application/json' -d '{"idLoyaltyCard": 1, "idsShops": [1,2,3], "discount": 20, "expirationDate": "2025-12-31T23:59:59"}')
echo "POST coupon response: $response"

# Step 3: Check if the coupon was created and get ID
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all coupons: $response"
coupon_id=$(echo "$response" | grep -oP '"id":\s*\K\d+')
echo "Retrieved coupon ID from GET all: $coupon_id"
[ -z "$coupon_id" ] && { echo "Test failed: could not retrieve coupon ID"; exit 1; }

# Step 4: Get coupon by ID
response=$(curl -s -X GET "$API_URL/$coupon_id" -H 'accept: application/json')
echo "GET coupon by ID: $response"
echo "$response" | grep -q "\"id\":$coupon_id" || { echo "Test failed: coupon not found by ID"; exit 1; }

# Step 5: Delete the coupon
response=$(curl -s -X DELETE "$API_URL/$coupon_id" -H 'accept: application/json')
echo "DELETE coupon $coupon_id: $response"

# Step 6: Check if the list is empty again
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json' | tr -d '%')
echo "GET all coupons after delete: $response"
[ "$response" = "[]" ] || { echo "Test failed: expected empty list after delete"; exit 1; }

echo "All tests passed successfully!"