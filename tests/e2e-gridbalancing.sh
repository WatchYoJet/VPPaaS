#!/bin/bash

# Usage: bash tests/e2e-gridbalancing.sh
# Prerequisites: Deploy.sh has been run; account1-addresses.env exists.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/get-addresses.sh"

KONG="http://$KONG_DNS:8000"
KAFKA_BROKER=$(echo "$KAFKA_BROKERS" | cut -d',' -f1)
KAFKA_DIR="/tmp/kafka-tools"
PASS=0; FAIL=0
CREATED_GZ_IDS=()

#  helpers 
sep()  { echo ""; echo "─────────"; }
fail() { echo "   FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "   PASS: $1"; PASS=$((PASS + 1)); }

cleanup() {
  sep
  echo "=== Cleanup ==="
  for id in "${CREATED_GZ_IDS[@]}"; do
    [ -z "$id" ] && continue
    HTTP=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" -X DELETE "$KONG/GridZone/$id" || echo "000")
    echo "  DELETE /GridZone/$id  HTTP $HTTP"
  done
}
trap cleanup EXIT

#  Step 1: GridZones 
sep
echo "=== Step 1: Create GridZones ==="
echo ""
echo "  Target: POST $KONG/GridZone"
echo "  Deficit zone : E2E-LISBON-EX  operator=1  postal=1400  safetyThreshold=100 kW  maxCapacity=1000 kW"
echo "  Surplus zone : E2E-LISBON-SO  operator=5  postal=1401  safetyThreshold=400 kW  maxCapacity=1000 kW"
echo "  Neighbour check: |1400 - 1401| = 1  "
echo ""

echo "   Creating E2E-LISBON-EX..."
GZ_EX_BODY=$(curl -s --max-time 15 -X POST "$KONG/GridZone" \
  -H 'Content-Type: application/json' \
  -d '{"name":"E2E-LISBON-EX","utilityOperatorId":1,"maxCapacity":1000,"boundaries":"","safetyThreshold":100,"postalCode":"1400"}' \
  -w "\nHTTP %{http_code}" || echo -e "\nHTTP 000")
echo "     Response: $(echo "$GZ_EX_BODY" | head -1)"
echo "     Status  : $(echo "$GZ_EX_BODY" | tail -1)"
GZ_EX_CODE=$(echo "$GZ_EX_BODY" | tail -1 | grep -oP '\d+')
GZ_EX_JSON=$(echo "$GZ_EX_BODY" | head -1)
GZ_EX_ID=$(echo "$GZ_EX_JSON" | grep -oP '"id":\s*\K\d+' | head -1)
if [ "$GZ_EX_CODE" = "201" ] || [ "$GZ_EX_CODE" = "200" ]; then
  CREATED_GZ_IDS+=("$GZ_EX_ID")
  pass "E2E-LISBON-EX created (id=$GZ_EX_ID)"
else
  fail "E2E-LISBON-EX: HTTP $GZ_EX_CODE"
fi

echo ""
echo "   Creating E2E-LISBON-SO..."
GZ_SO_BODY=$(curl -s --max-time 15 -X POST "$KONG/GridZone" \
  -H 'Content-Type: application/json' \
  -d '{"name":"E2E-LISBON-SO","utilityOperatorId":5,"maxCapacity":1000,"boundaries":"","safetyThreshold":400,"postalCode":"1401"}' \
  -w "\nHTTP %{http_code}" || echo -e "\nHTTP 000")
echo "     Response: $(echo "$GZ_SO_BODY" | head -1)"
echo "     Status  : $(echo "$GZ_SO_BODY" | tail -1)"
GZ_SO_CODE=$(echo "$GZ_SO_BODY" | tail -1 | grep -oP '\d+')
GZ_SO_JSON=$(echo "$GZ_SO_BODY" | head -1)
GZ_SO_ID=$(echo "$GZ_SO_JSON" | grep -oP '"id":\s*\K\d+' | head -1)
if [ "$GZ_SO_CODE" = "201" ] || [ "$GZ_SO_CODE" = "200" ]; then
  CREATED_GZ_IDS+=("$GZ_SO_ID")
  pass "E2E-LISBON-SO created (id=$GZ_SO_ID)"
else
  fail "E2E-LISBON-SO: HTTP $GZ_SO_CODE"
fi

echo ""
echo "   Verifying GridZones are stored..."
GZ_LIST=$(curl -s --max-time 15 "$KONG/GridZone" || echo "[]")
echo "     All GridZones:"
echo "$GZ_LIST" | python3 -c "
import sys, json
try:
    zones = json.load(sys.stdin)
    for z in zones:
        print(f'       id={z.get(\"id\",\"?\")}  name={z.get(\"name\",\"?\")}  postal={z.get(\"postalCode\",\"N/A\")}  threshold={z.get(\"safetyThreshold\",\"N/A\")} kW  operator={z.get(\"utilityOperatorId\",\"?\")}')
except: print('       (could not parse)')
" 2>/dev/null

#  Step 2: Telemetry consumer 
sep
echo "=== Step 2: Register Telemetry consumer for topic 1-ArcoCegoLisbon ==="
echo ""
echo "   POST $KONG/Telemetry/Consume  {TopicName: '1-ArcoCegoLisbon'}"
CONSUME_RESP=$(curl -s --max-time 15 -X POST "$KONG/Telemetry/Consume" \
  -H 'Content-Type: application/json' \
  -d '{"TopicName":"1-ArcoCegoLisbon"}' \
  -w "\nHTTP %{http_code}" || echo -e "\nHTTP 000")
echo "     Response: $(echo "$CONSUME_RESP" | head -1)"
echo "     Status  : $(echo "$CONSUME_RESP" | tail -1)"
CONSUME_CODE=$(echo "$CONSUME_RESP" | tail -1 | grep -oP '\d+')
if [ "$CONSUME_CODE" = "200" ] || [ "$CONSUME_CODE" = "204" ]; then
  pass "Consumer registered — Kafka messages on 1-ArcoCegoLisbon will be persisted to DB"
else
  fail "Telemetry/Consume HTTP $CONSUME_CODE (may already be registered — continuing)"
fi
sleep 2

#  Step 3: Kafka CLI 
sep
echo "=== Step 3: Kafka CLI ==="
echo ""
if [ ! -d "$KAFKA_DIR/bin" ]; then
  echo "  Downloading kafka_2.13-4.1.1..."
  mkdir -p "$KAFKA_DIR"
  curl -sL "https://downloads.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz" \
    | tar -xz -C "$KAFKA_DIR" --strip-components=1
  echo "  Done."
else
  echo "  Already present at $KAFKA_DIR"
fi
echo "  Kafka broker: $KAFKA_BROKER"

#  Step 4: EV charger load 
sep
echo "=== Step 4: Produce EV charger telemetry  E2E-LISBON-EX (deficit) ==="
echo ""
echo "  20 messages x 600 kW = 12 000 kW net load"
echo "  This exceeds safetyThreshold (100 kW)  zone qualifies as DEFICIT"
echo "  Topic: 1-ArcoCegoLisbon  |  grid_cell_id: E2E-LISBON-EX"
echo ""
for i in $(seq 1 20); do
  echo "{\"timeStamp\":\"2026-06-07T22:00:00\",\"asset_type\":\"EV_CHARGER\",\"asset_id\":\"1\",\"grid_cell_id\":\"E2E-LISBON-EX\",\"payload\":{\"connector_status\":\"CHARGING\",\"charging_power_kw\":600.0,\"session_energy_kwh\":50.0,\"ev_soc_percent\":30.0}}" \
    | "$KAFKA_DIR/bin/kafka-console-producer.sh" \
        --bootstrap-server "$KAFKA_BROKER" \
        --topic "1-ArcoCegoLisbon" 2>/dev/null
done
pass "20x EV_CHARGER produced to Kafka topic 1-ArcoCegoLisbon (grid_cell_id=E2E-LISBON-EX)"

#  Step 5: Solar generation 
sep
echo "=== Step 5: Produce solar generation telemetry  E2E-LISBON-SO (surplus) ==="
echo ""
echo "  20 messages x 800 kW generation = -16 000 kW net load"
echo "  This is below 0.5 x safetyThreshold (200 kW)  zone qualifies as SURPLUS"
echo "  Topic: 1-ArcoCegoLisbon  |  grid_cell_id: E2E-LISBON-SO"
echo ""
for i in $(seq 1 20); do
  echo "{\"timeStamp\":\"2026-06-07T22:00:00\",\"asset_type\":\"SOLAR\",\"asset_id\":\"2\",\"grid_cell_id\":\"E2E-LISBON-SO\",\"payload\":{\"generation_kw\":800.0,\"daily_yield_kwh\":200.0,\"ac_voltage_v\":230.0,\"grid_frequency_hz\":50.0}}" \
    | "$KAFKA_DIR/bin/kafka-console-producer.sh" \
        --bootstrap-server "$KAFKA_BROKER" \
        --topic "1-ArcoCegoLisbon" 2>/dev/null
done
pass "20x SOLAR produced to Kafka topic 1-ArcoCegoLisbon (grid_cell_id=E2E-LISBON-SO)"

#  Step 6: Wait 
sep
echo "=== Step 6: Waiting 10s for Telemetry consumer to flush to DB... ==="
sleep 10
echo "  Done."

#  Step 7: Verify telemetry 
sep
echo "=== Step 7: Verify telemetry rows in DB ==="
echo ""
echo "   GET $KONG/Telemetry"
TELEMETRY=$(curl -s --max-time 15 "$KONG/Telemetry" || echo "[]")
echo ""
echo "  Rows per zone:"
echo "$TELEMETRY" | python3 -c "
import sys, json
try:
    rows = json.load(sys.stdin)
    from collections import Counter
    counts = Counter(r.get('grid_cell_id','unknown') for r in rows)
    for zone, n in sorted(counts.items()):
        marker = '← E2E zone' if zone.startswith('E2E-') else ''
        print(f'    {zone}: {n} row(s)  {marker}')
    print(f'  Total rows in DB: {len(rows)}')
except Exception as e:
    print(f'  (parse error: {e})')
" 2>/dev/null

EX_COUNT=$(echo "$TELEMETRY" | grep -c '"E2E-LISBON-EX"' || true)
SO_COUNT=$(echo "$TELEMETRY" | grep -c '"E2E-LISBON-SO"' || true)
echo ""
if [ "$EX_COUNT" -gt 0 ] && [ "$SO_COUNT" -gt 0 ]; then
  pass "E2E-LISBON-EX: $EX_COUNT row(s)  |  E2E-LISBON-SO: $SO_COUNT row(s)  — both zones have telemetry"
else
  fail "Missing telemetry — E2E-LISBON-EX=$EX_COUNT, E2E-LISBON-SO=$SO_COUNT"
fi

# Step 8: Trigger recommendation
sep
echo "=== Step 8: Trigger recommendation engine ==="
echo ""
echo "   POST $KONG/GridBalancing/recommend"
echo "  (GridBalancing calls UtilityOperator directly to fetch GridZones)"
echo ""
RECOMMEND_RESP=$(curl -s --max-time 30 -w "\nHTTP %{http_code}" -X POST "$KONG/GridBalancing/recommend" \
  -H 'Content-Type: application/json' \
  -H 'accept: application/json' || echo -e "\nHTTP 000")
RECOMMEND_CODE=$(echo "$RECOMMEND_RESP" | tail -1 | grep -oP '\d+')
RECOMMEND_BODY=$(echo "$RECOMMEND_RESP" | sed '$d')

echo "  Status: HTTP $RECOMMEND_CODE"
echo "  Response body:"
echo "$RECOMMEND_BODY" | python3 -m json.tool 2>/dev/null | sed 's/^/    /' || echo "    $RECOMMEND_BODY"
echo ""

if [ "$RECOMMEND_CODE" = "200" ]; then
  pass "POST /GridBalancing/recommend  HTTP 200"
else
  fail "POST /GridBalancing/recommend  HTTP $RECOMMEND_CODE (expected 200)"
fi

# Step 9: Non-empty check 
sep
echo "=== Step 9: Assert recommendations are non-empty ==="
echo ""
REC_COUNT=$(echo "$RECOMMEND_BODY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    recs = data.get('recommendations', [])
    if isinstance(recs, str):
        recs = json.loads(recs)
    print(len(recs))
except:
    print(0)
" 2>/dev/null || echo "0")

if [ "$REC_COUNT" -gt 0 ]; then
  pass "$REC_COUNT recommendation(s) returned"
else
  fail "Recommendations list is empty"
  echo ""
  echo "  Diagnostic hints:"
  echo "    • Verify GridZone postalCode/safetyThreshold fields are present in GET /GridZone response"
  echo "    • Verify GridBalancing is using the current UtilityOperator URL (check terraform.tfvars)"
  echo "    • Check GridBalancing container logs for errors"
fi

#  Step 10: Field validation + summary 
sep
echo "=== Step 10: Validate recommendation fields ==="
echo ""
python3 - <<PYEOF
import sys, json

body = """$RECOMMEND_BODY"""
try:
    data = json.loads(body)
    recs = data.get("recommendations", [])
    if isinstance(recs, str):
        recs = json.loads(recs)
except Exception as e:
    print(f"   Could not parse response: {e}")
    sys.exit(1)

if not recs:
    print("  (no recommendations to validate)")
    sys.exit(0)

required = {"deficitZoneId", "surplusZoneId", "recommendedActionKw"}
errors = []
for i, r in enumerate(recs):
    missing = required - set(r.keys())
    if missing:
        errors.append(f"  rec[{i}] missing fields: {missing}")
    if r.get("recommendedActionKw", 0) <= 0:
        errors.append(f"  rec[{i}] recommendedActionKw must be > 0, got {r.get('recommendedActionKw')}")

if errors:
    print("   Schema errors:")
    for e in errors: print(e)
    sys.exit(1)

print(f"   All {len(recs)} recommendation(s) have valid fields")
print()
print("  ┌──────────────┐")
print("  │  Recommendation Results                                 │")
print("  ├──────────────────┬──────────────────┬───────────────────┤")
print("  │  Deficit Zone    │  Surplus Zone    │  Transfer (kW)    │")
print("  ├──────────────────┼──────────────────┼───────────────────┤")
for r in recs:
    d = r['deficitZoneId'][:16].ljust(16)
    s = r['surplusZoneId'][:16].ljust(16)
    kw = str(r['recommendedActionKw']).ljust(17)
    print(f"  │  {d}  │  {s}  │  {kw}  │")
print("  └──────────────────┴──────────────────┴───────────────────┘")
PYEOF

RC=$?
if [ $RC -eq 0 ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi

#  Final summary 
sep
echo ""
echo "  ╔══════════════════════════════════╗"
echo "  ║  E2E Grid Balancing Test Results  ║"
echo "  ╠══════════════════════════════════╣"
printf   "  ║   PASS: %-3s   FAIL: %-3s       ║\n" "$PASS" "$FAIL"
echo "  ╚══════════════════════════════════╝"
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "  All tests passed — Grid Balancing recommendation pipeline is working end-to-end."
else
  echo "  Some tests FAILED — see output above for details."
  exit 1
fi
