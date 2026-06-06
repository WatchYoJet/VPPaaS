#!/bin/bash
source "$(dirname "$0")/get-addresses.sh"
API_URL="http://$TELEMETRY_DNS:8080/Telemetry"
KAFKA_BROKER=$(echo "$KAFKA_BROKERS" | cut -d',' -f1)
TOPIC='1-ArcoCegoLisbon'

response=$(curl -s -X POST "$API_URL/Consume" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{\"TopicName\":\"$TOPIC\"}")
echo "POST /Consume (register Kafka consumer for $TOPIC): $response"

echo "Starting simulator for 30 seconds..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
java -jar "$SCRIPT_DIR/VPPaaSSimulator.jar" \
  --broker-list "$KAFKA_BROKER" \
  --filterprefix 1 \
  --throughput 2 &
SIM_PID=$!
sleep 30
kill $SIM_PID 2>/dev/null

response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all telemetry events: $response"

id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
if [ -n "$id" ]; then
  response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
  echo "GET telemetry event by ID $id: $response"
  echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: telemetry not found by ID"; exit 1; }
else
  echo "No telemetry events yet — simulator may need more time or Kafka brokers may still be starting"
  exit 1
fi

echo "All tests passed successfully!"
