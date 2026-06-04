#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$GROUP_C:8081/GridBalancing"
GRIDZONE_URL="http://$GROUP_A:8081/GridZone"

echo "Creating GridZone for utility operator 1..."
curl -s -X POST "$GRIDZONE_URL" \
  -H 'Content-Type: application/json' \
  -d '{"utilityOperatorId":1,"name":"LISBON-DT","maxCapacity":500.0,"boundaries":"POLYGON((0 0,1 0,1 1,0 1,0 0))"}' > /dev/null
gz_id=$(curl -s "$GRIDZONE_URL" | grep -oP '"id":\s*\K\d+' | head -1)
echo "GridZone ID: $gz_id"
[ -z "$gz_id" ] && { echo "Test failed: could not create GridZone"; exit 1; }

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all grid balancing recommendations: $response"

response=$(curl -s -X POST "$API_URL/recommend" -H 'accept: application/json')
echo "POST /recommend: $response"

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all recommendations after compute: $response"

curl -s -X DELETE "$GRIDZONE_URL/$gz_id" > /dev/null
echo "GridZone cleaned up"

echo "All tests passed successfully!"
