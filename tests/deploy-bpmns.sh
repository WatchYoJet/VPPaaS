#!/bin/bash
# Deploys all BPMN processes and forms in BPMN/ to Camunda.
# Substitutes DNS placeholders with live addresses from account1-addresses.env.
# Sends BPMNs and forms in separate requests to stay within Camunda's multipart limits.
#
# Usage: bash tests/deploy-bpmns.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/get-addresses.sh"

CAMUNDA_API="http://$CAMUNDA_DNS:8080"
AUTH="-u demo:demo"

deploy() {
  local label="$1"; shift
  local resources=("$@")
  echo ""
  echo "--- Deploying $label ---"
  local args=()
  for r in "${resources[@]}"; do
    args+=(-F "resources=@$r")
  done
  local http_code
  http_code=$(curl -s -o /tmp/deploy_response.json -w "%{http_code}" \
    $AUTH \
    -X POST "$CAMUNDA_API/v2/deployments" \
    "${args[@]}")
  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "[OK] $label deployed (HTTP $http_code)"
  else
    echo "[FAIL] $label deployment failed (HTTP $http_code)"
    cat /tmp/deploy_response.json 2>/dev/null
    echo ""
    echo "Check Camunda Operate: $CAMUNDA_API/operate"
    exit 1
  fi
}

echo "=== Deploying BPMN processes and forms ==="
echo "Camunda: $CAMUNDA_API"

# ── Substitute placeholders in all BPMNs and stage to /tmp ───────────────────
BPMN_FILES=()

while IFS= read -r -d '' bpmn; do
  tmpfile="/tmp/$(basename "$bpmn")"
  sed \
    -e "s|CAMUNDA_DNS_PLACEHOLDER|$CAMUNDA_DNS|g" \
    -e "s|KONG_DNS_PLACEHOLDER|$KONG_DNS|g" \
    -e "s|FLEXIBILITYEVENT_DNS_PLACEHOLDER|$FLEXIBILITYEVENT_DNS|g" \
    -e "s|FLEXIBILITYFORECASTING_DNS_PLACEHOLDER|$OLLAMA_DNS|g" \
    -e "s|ENERGYANALYTICS_DNS_PLACEHOLDER|$ENERGYANALYTICS_DNS|g" \
    -e "s|GRIDBALANCING_DNS_PLACEHOLDER|$GRIDBALANCING_DNS|g" \
    "$bpmn" > "$tmpfile"
  BPMN_FILES+=("$tmpfile")
  echo "  + $(basename "$bpmn")"
done < <(find "$ROOT/BPMN" -name "*.bpmn" -not -path "*/Generic-BPMN-Patterns-For-Your-Reuse/*" -print0)

# ── Collect forms ─────────────────────────────────────────────────────────────
FORM_FILES=()
for form in "$ROOT/BPMN/forms/"*.form; do
  [ -f "$form" ] || continue
  FORM_FILES+=("$form")
  echo "  + $(basename "$form")"
done

# ── Deploy BPMNs first, then forms (separate requests to avoid size limits) ───
deploy "BPMNs (${#BPMN_FILES[@]} files)" "${BPMN_FILES[@]}"
deploy "Forms (${#FORM_FILES[@]} files)" "${FORM_FILES[@]}"

echo ""
echo "=== All deployments successful ==="
echo "Camunda Operate: $CAMUNDA_API/operate"
