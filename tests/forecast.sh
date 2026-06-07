#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$KONG_DNS:8000/FlexibilityForecasting"

echo "Calling AI forecast endpoint (may take up to 60s)..."

response=$(curl -s -X POST "$API_URL/forecast" -H 'accept: application/json')
echo "POST /forecast response: $response"
echo "$response" | grep -q '"forecast"' || { echo "Test failed: no forecast in response"; exit 1; }

echo "All tests passed successfully!"
