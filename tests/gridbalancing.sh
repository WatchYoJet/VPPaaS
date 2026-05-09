#!/bin/bash

API_URL='http://<GRIDBALANCING_EC2>:8080/GridBalancing'

# Note: Requires telemetry data AND GridZone rows in the database
# Use tests\VPPaaSSimulator.jar for this via 
# java -jar "./VPPaaSSimulator.jar" \                            
#  --broker-list <KAFKA_EC2>:9092 \
#  --throughput 30 \
#  (optional) --filterprefix 1

# Step 1: GET all recommendations (may be empty before first compute)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all grid balancing recommendations: $response"

# Step 2: Generate recommendations
response=$(curl -s -X POST "$API_URL/recommend" -H 'accept: application/json')
echo "POST /recommend: $response"

# Step 3: GET all after compute
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all recommendations after compute: $response"
[ "$response" = "[]" ] && { echo "No recommendations generated — ensure GridZone and telemetry data exist"; exit 1; }

echo "All tests passed successfully!"
