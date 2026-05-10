#!/bin/bash

API_URL='http://ec2-34-230-37-40.compute-1.amazonaws.com:8080/EnergyAnalytics'

# Note: Telemetry data must exist for analytics to produce results

# Step 1: GET all analytics (may be empty before first compute)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all energy analytics: $response"

# Step 2: Trigger computation (aggregates telemetry, persists results, publishes to Kafka)
response=$(curl -s -X POST "$API_URL/compute" -H 'accept: application/json')
echo "POST /compute: $response"

# Step 3: GET all after compute
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all energy analytics after compute: $response"
[ "$response" = "[]" ] && { echo "No analytics generated — ensure telemetry data exists first"; exit 1; }

echo "All tests passed successfully!"
