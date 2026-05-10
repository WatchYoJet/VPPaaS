#!/bin/bash

API_URL='http://ec2-3-82-214-98.compute-1.amazonaws.com:8080/FlexibilityEvent'

# Note: Telemetry data must exist before triggering (run telemetry.sh + EventProducer first)

# Step 1: GET all events (may be empty before first trigger)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all flexibility events: $response"

# Step 2: Trigger event analysis (reads telemetry, creates events, publishes to Kafka)
response=$(curl -s -X POST "$API_URL/trigger" -H 'accept: application/json')
echo "POST /trigger: $response"

# Step 3: GET all events after trigger
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all flexibility events after trigger: $response"
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
[ -z "$id" ] && { echo "No events generated — ensure telemetry data exists first"; exit 1; }

# Step 4: GET by ID
response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
echo "GET flexibility event by ID $id: $response"
echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: event not found by ID"; exit 1; }

echo "All tests passed successfully!"
