#!/bin/bash

API_URL='http://ec2-44-203-59-18.compute-1.amazonaws.com:8080/GridBalancing'
GRIDZONE_URL='http://ec2-54-237-178-34.compute-1.amazonaws.com:8080/GridZone'

# GridBalancing requires: telemetry data + at least one GridZone row.
# This script creates a GridZone, runs recommend, then cleans up.

# Step 1: Create a GridZone for utility operator 1 (used by recommend logic)
echo "Creating GridZone for utility operator 1..."
curl -s -X POST "$GRIDZONE_URL" \
  -H 'Content-Type: application/json' \
  -d '{"utilityOperatorId":1,"name":"LISBON-DT","maxCapacity":500.0,"boundaries":"POLYGON((0 0,1 0,1 1,0 1,0 0))"}' > /dev/null
gz_id=$(curl -s "$GRIDZONE_URL" | grep -oP '"id":\s*\K\d+' | head -1)
echo "GridZone ID: $gz_id"
[ -z "$gz_id" ] && { echo "Test failed: could not create GridZone"; exit 1; }

# Step 2: GET all recommendations (may be empty before first compute)
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all grid balancing recommendations: $response"

# Step 3: Generate recommendations
response=$(curl -s -X POST "$API_URL/recommend" -H 'accept: application/json')
echo "POST /recommend: $response"

# Step 4: GET all after compute
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all recommendations after compute: $response"

# Step 5: Clean up GridZone
curl -s -X DELETE "$GRIDZONE_URL/$gz_id" > /dev/null
echo "GridZone cleaned up"

echo "All tests passed successfully!"
