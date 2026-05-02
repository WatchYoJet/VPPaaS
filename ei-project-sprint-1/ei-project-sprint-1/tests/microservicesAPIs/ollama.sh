#!/bin/bash

# Replace with your actual EC2 DNS name
EC2_DNS="ec2-34-207-107-73.compute-1.amazonaws.com"
API_URL="http://$EC2_DNS:11434/api/generate"

# Send request
response=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}')

echo "Response: $response"

# Check if response is non-empty
[ -z "$response" ] && { echo "Test failed: No response from server"; exit 1; }

echo "$response" | grep -q '"response"' || { echo "Test failed: 'response' field not found"; exit 1; }

echo "All tests passed successfully!"
