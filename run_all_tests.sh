#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
TESTS="$ROOT/tests"

source "$TESTS/get-addresses.sh"

PASS=0
FAIL=0
SKIP=0

run() {
  local name=$1
  local script=$2
  echo ""
  echo "================================================"
  echo " Running: $name"
  echo "================================================"
  if bash "$script"; then
    echo "[PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

# ── Basic CRUD tests ──────────────────────────────────────────────────────────
run "Prosumer"        "$TESTS/prosumer.sh"
run "UtilityOperator" "$TESTS/utilityoperator.sh"
run "GridZone"        "$TESTS/gridzone.sh"
run "AssetLink"       "$TESTS/assetlink.sh"

# ── Telemetry: register consumer, run simulator, wait for data ────────────────
echo ""
echo "================================================"
echo " Populating Telemetry via Simulator"
echo "================================================"

curl -s -X POST "http://$KONG_DNS:8000/Telemetry/Consume" \
  -H "Content-Type: application/json" \
  -d '{"TopicName":"1-ArcoCegoLisbon"}'
echo " Consumer registered"

sleep 3

java -jar "$TESTS/VPPaaSSimulator.jar" \
  --broker-list "$KAFKA_BROKERS" \
  --filterprefix 1 \
  --throughput 2 &
SIM_PID=$!
echo " Simulator started (PID $SIM_PID), running 30s..."
sleep 30
kill $SIM_PID 2>/dev/null
echo " Simulator stopped"

TELEMETRY_COUNT=$(curl -s "http://$KONG_DNS:8000/Telemetry" | \
  python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
echo " Telemetry events in DB: $TELEMETRY_COUNT"

if [ "$TELEMETRY_COUNT" -gt 0 ]; then
  echo "[PASS] Telemetry"
  PASS=$((PASS + 1))
else
  echo "[FAIL] Telemetry — no events found after simulator run"
  FAIL=$((FAIL + 1))
fi

# ── Tests that depend on telemetry data ───────────────────────────────────────
run "FlexibilityEvent" "$TESTS/flexibilityevent.sh"
run "EnergyAnalytics"  "$TESTS/energyanalytics.sh"
run "GridBalancing"    "$TESTS/gridbalancing.sh"

# ── Forecast (requires Ollama + llama3.2) ─────────────────────────────────────
echo ""
echo "================================================"
echo " Checking Ollama model"
echo "================================================"
MODEL_READY=$(curl -s "http://$OLLAMA_DNS:11434/api/tags" | python3 -c \
  "import sys,json; models=[m['name'] for m in json.load(sys.stdin).get('models',[])]; print('yes' if any('llama3.2' in m for m in models) else 'no')" \
  2>/dev/null || echo "no")

if [ "$MODEL_READY" = "yes" ]; then
  run "Forecast" "$TESTS/forecast.sh"
else
  echo "[SKIP] Forecast — llama3.2 not loaded on Ollama yet"
  echo "       Pull it with: curl -X POST http://$OLLAMA_DNS:11434/api/pull -d '{\"name\":\"llama3.2\"}'"
  SKIP=$((SKIP + 1))
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo " RESULTS: $PASS passed  |  $FAIL failed  |  $SKIP skipped"
echo "================================================"

[ "$FAIL" -eq 0 ]
