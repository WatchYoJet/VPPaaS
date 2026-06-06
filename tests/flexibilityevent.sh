#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$FLEXIBILITYEVENT_DNS:8080/FlexibilityEvent"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all flexibility events: $response"

response=$(curl -s -X POST "$API_URL/trigger" -H 'accept: application/json')
echo "POST /trigger: $response"
echo "$response" | grep -q '"processed"' || { echo "Test failed: unexpected response from trigger (expected JSON with 'processed')"; exit 1; }

count=$(echo "$response" | grep -oP '"processed":\s*\K\d+')
echo "Events generated: $count"

if [ "$count" -gt 0 ]; then
  response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
  echo "GET all flexibility events after trigger: $response"
  id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
  if [ -n "$id" ]; then
    response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
    echo "GET flexibility event by ID $id: $response"
    echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: event not found by ID"; exit 1; }
  fi
else
  echo "(No events generated — no BATTERY/SOLAR telemetry conditions met; trigger endpoint is healthy)"
fi

echo "All tests passed successfully!"
