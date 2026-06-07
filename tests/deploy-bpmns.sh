#!/bin/bash
# Deploys all BPMN processes and forms in BPMN/ to Camunda in a single request.
# Substitutes DNS placeholders with live addresses from account1-addresses.env.
#
# Usage: bash tests/deploy-bpmns.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/get-addresses.sh"

CAMUNDA_API="http://$CAMUNDA_DNS:8080"
AUTH="-u demo:demo"

echo "=== Deploying BPMN processes and forms ==="
echo "Camunda: $CAMUNDA_API"
echo ""

# ── Substitute placeholders in all BPMNs and stage to /tmp ───────────────────
RESOURCES=""

for bpmn in "$ROOT/BPMN/"*.bpmn; do
  [ -f "$bpmn" ] || continue
  tmpfile="/tmp/$(basename "$bpmn")"

  sed \
    -e "s|CAMUNDA_DNS_PLACEHOLDER|$CAMUNDA_DNS|g" \
    -e "s|KONG_DNS_PLACEHOLDER|$KONG_DNS|g" \
    -e "s|FLEXIBILITYEVENT_DNS_PLACEHOLDER|$FLEXIBILITYEVENT_DNS|g" \
    -e "s|FLEXIBILITYFORECASTING_DNS_PLACEHOLDER|$OLLAMA_DNS|g" \
    -e "s|ENERGYANALYTICS_DNS_PLACEHOLDER|$ENERGYANALYTICS_DNS|g" \
    -e "s|GRIDBALANCING_DNS_PLACEHOLDER|$GRIDBALANCING_DNS|g" \
    "$bpmn" > "$tmpfile"

  RESOURCES="$RESOURCES -F resources=@$tmpfile"
  echo "  + $(basename "$bpmn")"
done

# ── Include all forms ─────────────────────────────────────────────────────────
for form in "$ROOT/BPMN/forms/"*.form; do
  [ -f "$form" ] || continue
  RESOURCES="$RESOURCES -F resources=@$form"
  echo "  + $(basename "$form")"
done

echo ""

# ── Single deployment call ────────────────────────────────────────────────────
http_code=$(curl -s -o /tmp/deploy_response.json -w "%{http_code}" \
  $AUTH \
  -X POST "$CAMUNDA_API/v2/deployments" \
  $RESOURCES)

if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
  echo "[OK] Deployment successful (HTTP $http_code)"
else
  echo "[FAIL] Deployment failed (HTTP $http_code)"
  cat /tmp/deploy_response.json 2>/dev/null
  echo ""
  echo "Check Camunda Operate: $CAMUNDA_API/operate"
  exit 1
fi
