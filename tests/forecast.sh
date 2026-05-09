#!/bin/bash

API_URL='http://<OLLAMA_EC2>:8080/FlexibilityForecasting'

# Note: FlexibilityEvent data must exist (run flexibilityevent.sh first)
# Note: First call may take 1-2 minutes (Ollama CPU inference with llama3.2)

echo "Calling AI forecast endpoint (may take 1-2 minutes)..."

# Step 1: POST /forecast (reads last 5 flexibility events, sends to Ollama)
response=$(curl -s -X POST "$API_URL/forecast" -H 'accept: application/json')
echo "POST /forecast response: $response"
echo "$response" | grep -q '"forecast"' || { echo "Test failed: no forecast in response"; exit 1; }

echo "All tests passed successfully!"
