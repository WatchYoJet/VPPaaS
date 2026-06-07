#!/bin/bash
# Seed GridZones and telemetry data for the Grid Balancing Recommendation demo.
# Creates LISBON-EX (deficit, operator 1) and LISBON-SO (surplus, operator 5),
# then populates telemetry via Kafka so the recommendation engine fires.
#
# Usage: bash tests/seed-gridbalancing.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/get-addresses.sh"

KONG="http://$KONG_DNS:8000"
KAFKA_BROKER=$(echo "$KAFKA_BROKERS" | cut -d',' -f1)
KAFKA_DIR="/tmp/kafka-tools"

echo "=== Step 1: Create GridZones ==="

echo "Creating LISBON-EX (deficit zone, ArcoCegoLisbon, postal 1400)..."
curl -s -X POST "$KONG/GridZone" \
  -H 'Content-Type: application/json' \
  -d '{"name":"LISBON-EX","utilityOperatorId":1,"maxCapacity":1000,"boundaries":"","safetyThreshold":100,"postalCode":"1400"}'
echo ""

echo "Creating LISBON-SO (surplus zone, SolarGrid SA, postal 1401)..."
curl -s -X POST "$KONG/GridZone" \
  -H 'Content-Type: application/json' \
  -d '{"name":"LISBON-SO","utilityOperatorId":5,"maxCapacity":1000,"boundaries":"","safetyThreshold":400,"postalCode":"1401"}'
echo ""

echo ""
echo "=== Step 2: Kafka CLI ==="
if [ ! -d "$KAFKA_DIR" ]; then
  echo "Downloading Kafka CLI..."
  mkdir -p "$KAFKA_DIR"
  curl -sL "https://downloads.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz" \
    | tar -xz -C "$KAFKA_DIR" --strip-components=1
  echo "Done."
else
  echo "Already present at $KAFKA_DIR"
fi

echo ""
echo "=== Step 3: Register Telemetry consumer ==="
curl -s -X POST "$KONG/Telemetry/Consume" \
  -H 'Content-Type: application/json' \
  -d '{"TopicName":"1-ArcoCegoLisbon"}'
echo ""
sleep 2

echo ""
echo "=== Step 4: Produce EV charger load for LISBON-EX (deficit) ==="
# 20 × 600 kW = 12 000 kW net load >> safetyThreshold 100 kW
for i in $(seq 1 20); do
  echo '{"timeStamp":"2026-06-07T22:00:00","asset_type":"EV_CHARGER","asset_id":"1","grid_cell_id":"LISBON-EX","payload":{"connector_status":"CHARGING","charging_power_kw":600.0,"session_energy_kwh":50.0,"ev_soc_percent":30.0}}' \
    | $KAFKA_DIR/bin/kafka-console-producer.sh \
        --bootstrap-server "$KAFKA_BROKER" \
        --topic "1-ArcoCegoLisbon" 2>/dev/null
done
echo "20× EV_CHARGER → LISBON-EX (600 kW each)"

echo ""
echo "=== Step 5: Produce solar generation for LISBON-SO (surplus) ==="
# 20 × 800 kW generation → net load = -16 000 kW << 0.5 × 400 kW threshold
for i in $(seq 1 20); do
  echo '{"timeStamp":"2026-06-07T22:00:00","asset_type":"SOLAR","asset_id":"2","grid_cell_id":"LISBON-SO","payload":{"generation_kw":800.0,"daily_yield_kwh":200.0,"ac_voltage_v":230.0,"grid_frequency_hz":50.0}}' \
    | $KAFKA_DIR/bin/kafka-console-producer.sh \
        --bootstrap-server "$KAFKA_BROKER" \
        --topic "1-ArcoCegoLisbon" 2>/dev/null
done
echo "20× SOLAR → LISBON-SO (800 kW generation each)"

echo ""
echo "=== Step 6: Wait for consumer to persist to DB ==="
sleep 8

echo ""
echo "=== Telemetry check ==="
echo "Zones visible to recommendation engine:"
curl -s "$KONG/Telemetry" | python3 -c "
import sys, json
rows = json.load(sys.stdin)
zones = sorted(set(r['grid_cell_id'] for r in rows))
for z in zones: print(' ', z)
print(f'  ({len(rows)} total rows)')
"

echo ""
echo "=== All done ==="
echo ""
echo "  Deficit zone : LISBON-EX  postal 1400  safetyThreshold 100 kW  (operator 1 - ArcoCegoLisbon)"
echo "  Surplus zone : LISBON-SO  postal 1401  safetyThreshold 400 kW  (operator 5 - SolarGrid SA)"
echo "  Neighbours   : |1400 - 1401| = 1 ✓"
echo ""
echo "  Now go to Camunda Tasklist and start 'GridBalancingRecommendation':"
echo "  http://$CAMUNDA_DNS:8080/tasklist"
