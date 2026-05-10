#!/bin/bash

API_URL='http://ec2-23-22-105-201.compute-1.amazonaws.com:8080/FlexibilityForecasting'

# Note: FlexibilityEvent data must exist (run flexibilityevent.sh first)

echo "Calling AI forecast endpoint (may take some time)..."

# Step 1: POST /forecast (reads last 5 flexibility events, sends to Ollama)
response=$(curl -s -X POST "$API_URL/forecast" -H 'accept: application/json')
echo "POST /forecast response: $response"
echo "$response" | grep -q '"forecast"' || { echo "Test failed: no forecast in response"; exit 1; }

echo "All tests passed successfully!"
