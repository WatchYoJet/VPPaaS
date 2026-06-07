#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$KONG_DNS:8000/GridBalancing"
GRIDZONE_URL="http://$KONG_DNS:8000/GridZone"

PASS=0; FAIL=0; SKIP=0

echo "Creating GridZone for utility operator 1..."
curl -s -X POST "$GRIDZONE_URL" \
  -H 'Content-Type: application/json' \
  -d '{"utilityOperatorId":1,"name":"LISBON-DT","maxCapacity":500.0,"boundaries":"POLYGON((0 0,1 0,1 1,0 1,0 0))"}' > /dev/null
gz_id=$(curl -s "$GRIDZONE_URL" | grep -oP '"id":\s*\K\d+' | head -1)
echo "GridZone ID: $gz_id"
[ -z "$gz_id" ] && { echo "Test failed: could not create GridZone"; exit 1; }

echo "--- Test: GET /GridBalancing ---"
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "Response: $response"
if echo "$response" | grep -q '\['; then
    echo "PASS"; ((PASS++))
else
    echo "FAIL: expected JSON array"; ((FAIL++))
fi

echo "--- Test: POST /GridBalancing/recommend ---"
RECOMMEND_RESPONSE=$(curl -s -X POST "$API_URL/recommend" \
    -H 'Content-Type: application/json' \
    -H 'accept: application/json')
echo "Response: $RECOMMEND_RESPONSE"
if echo "$RECOMMEND_RESPONSE" | grep -q 'recommendations'; then
    echo "PASS"; ((PASS++))
else
    echo "FAIL: expected recommendations field"; ((FAIL++))
fi

echo "--- Test: POST /GridBalancing/act ---"
REC_ID=$(echo "$RECOMMEND_RESPONSE" | grep -oP '"id":\s*\K\d+' | head -1)
if [ -z "$REC_ID" ]; then
    echo "SKIP: No recommendations returned (no telemetry data in zones)"
    ((SKIP++))
else
    ACT_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H 'accept: application/json' \
        "$API_URL/act/$REC_ID")
    if [ "$ACT_HTTP" = "200" ] || [ "$ACT_HTTP" = "404" ]; then
        echo "PASS: act returned $ACT_HTTP (200=actioned, 404=no AssetLink in surplus zone)"
        ((PASS++))
    else
        echo "FAIL: act returned unexpected HTTP $ACT_HTTP"
        ((FAIL++))
    fi
fi

echo "--- Test: GET /GridBalancing (after recommend) ---"
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "Response: $response"
if echo "$response" | grep -q '\['; then
    echo "PASS"; ((PASS++))
else
    echo "FAIL"; ((FAIL++))
fi

curl -s -X DELETE "$GRIDZONE_URL/$gz_id" > /dev/null
echo "GridZone cleaned up"

echo ""
echo "Results: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ] && echo "All tests passed successfully!" || { echo "Some tests FAILED"; exit 1; }
