#!/bin/bash
# Run this script ON the AssetLink EC2 to debug Kafka connectivity.
# Usage: bash kafka-debug.sh
#
# It will:
#   1. Test TCP connectivity to each broker
#   2. Download Kafka CLI tools if not present
#   3. Create a test topic, produce a message, consume it back

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/get-addresses.sh"

BROKERS="$KAFKA_BROKERS"
TOPIC="debug-test-topic"
KAFKA_DIR="/tmp/kafka-debug"
KAFKA_VERSION="2.13-4.1.1"

echo "=== Step 1: TCP connectivity to each broker ==="
for broker in $(echo "$BROKERS" | tr ',' '\n'); do
  host=$(echo "$broker" | cut -d: -f1)
  port=$(echo "$broker" | cut -d: -f2)
  if nc -zv -w 5 "$host" "$port" 2>&1 | grep -q "succeeded\|open"; then
    echo "  [OK]   $broker reachable"
  else
    echo "  [FAIL] $broker NOT reachable"
  fi
done

echo ""
echo "=== Step 2: Install Kafka CLI tools ==="
if [ ! -d "$KAFKA_DIR" ]; then
  echo "  Downloading Kafka $KAFKA_VERSION..."
  mkdir -p "$KAFKA_DIR"
  curl -sL "https://downloads.apache.org/kafka/4.1.1/kafka_${KAFKA_VERSION}.tgz" \
    | tar -xz -C "$KAFKA_DIR" --strip-components=1
  echo "  Done."
else
  echo "  Already present at $KAFKA_DIR"
fi

echo ""
echo "=== Step 3: Create test topic ==="
"$KAFKA_DIR/bin/kafka-topics.sh" \
  --bootstrap-server "$BROKERS" \
  --create --if-not-exists \
  --topic "$TOPIC" \
  --partitions 1 \
  --replication-factor 1 \
  --command-timeout 10 \
  && echo "  [OK] Topic '$TOPIC' created (or already exists)" \
  || echo "  [FAIL] Could not create topic"

echo ""
echo "=== Step 4: List topics (confirm topic exists) ==="
"$KAFKA_DIR/bin/kafka-topics.sh" \
  --bootstrap-server "$BROKERS" \
  --list \
  --command-timeout 10

echo ""
echo "=== Step 5: Produce a test message ==="
echo "hello-from-assetlink-$(date +%s)" | \
  "$KAFKA_DIR/bin/kafka-console-producer.sh" \
    --bootstrap-server "$BROKERS" \
    --topic "$TOPIC" \
  && echo "  [OK] Message produced"

echo ""
echo "=== Step 6: Consume the message back (5 second timeout) ==="
"$KAFKA_DIR/bin/kafka-console-consumer.sh" \
  --bootstrap-server "$BROKERS" \
  --topic "$TOPIC" \
  --from-beginning \
  --max-messages 1 \
  --timeout-ms 5000 \
  && echo "  [OK] Message consumed" \
  || echo "  [FAIL] No message received within timeout"

echo ""
echo "=== Done ==="
