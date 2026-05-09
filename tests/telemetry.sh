#!/bin/bash

API_URL='http://<TELEMETRY_EC2>:8080/Telemetry'
TOPIC='1-ArcoCegoLisbon'

# Step 1: Register a Kafka consumer for the asset link topic
response=$(curl -s -X POST "$API_URL/Consume" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{\"TopicName\":\"$TOPIC\"}")
echo "POST /Consume (register Kafka consumer for $TOPIC): $response"

# Step 2: GET all telemetry events
response=$(curl -s -X GET "$API_URL" -H 'accept: application/json')
echo "GET all telemetry events: $response"

# Step 3: GET by ID if data exists
id=$(echo "$response" | grep -oP '"id":\s*\K\d+' | head -1)
if [ -n "$id" ]; then
  response=$(curl -s -X GET "$API_URL/$id" -H 'accept: application/json')
  echo "GET telemetry event by ID $id: $response"
  echo "$response" | grep -q "\"id\":$id" || { echo "Test failed: telemetry not found by ID"; exit 1; }
else
  echo "No telemetry events yet — run the EventProducer to populate data:"
  echo "  java -jar VPPaaS-EventProducer/VPPaaSSimulator.jar --broker-list <KAFKA_EC2>:9092 --filterprefix 1 --throughput 1"
fi

echo "All tests passed successfully!"
