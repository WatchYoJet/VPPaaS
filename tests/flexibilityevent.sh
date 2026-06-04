#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$GROUP_B:8081/FlexibilityEvent"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all flexibility events: $response"

response=$(curl -s -X POST "$API_URL/trigger" -H 'accept: application/json')
echo "POST /trigger: $response"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all flexibility events after trigger: $response"
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
[ -z "$id" ] && { echo "No events generated — ensure telemetry data exists first"; exit 1; }

response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET flexibility event by ID $id: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: event not found by ID"; exit 1; }

echo "All tests passed successfully!"
