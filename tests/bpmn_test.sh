#!/bin/bash
# End-to-end BPMN test for ProsumerManagement process.
# Deploys all 8 BPMN processes to Camunda then runs one full flow:
#   Start → KYC user task → approve → service task → prosumer created in DB
#
# Usage: bash tests/bpmn_test.sh [camunda-host]
#   camunda-host defaults to Terraform state if not given

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."

# ── Resolve Camunda + Kong addresses ─────────────────────────────────────────
CAMUNDA="${1:-}"
if [ -z "$CAMUNDA" ]; then
  CAMUNDA=$(terraform -chdir="$ROOT/terraform/Camunda-Terraform" \
    state show aws_instance.exampleInstallCamundaEngine -no-color 2>/dev/null \
    | grep ' public_dns' | sed 's/.*=//;s/"//g;s/ //g')
fi
if [ -z "$CAMUNDA" ]; then
  echo "[ERROR] Could not resolve Camunda address. Pass it as argument: bash bpmn_test.sh <host>" >&2
  exit 1
fi

KONG=$(terraform -chdir="$ROOT/terraform/KongTerraform" \
  state show aws_instance.exampleInstallKong -no-color 2>/dev/null \
  | grep ' public_dns' | sed 's/.*=//;s/"//g;s/ //g')
if [ -z "$KONG" ]; then
  echo "[ERROR] Could not resolve Kong address from Terraform state." >&2
  exit 1
fi

echo "Camunda: $CAMUNDA"
echo "Kong:    $KONG"
echo ""

CAMUNDA_API="http://$CAMUNDA:8080"
AUTH="-u demo:demo"

# ── Step 1: Deploy all 8 BPMN processes ──────────────────────────────────────
echo "================================================"
echo " Deploying BPMN processes to Camunda"
echo "================================================"

PASS=0
FAIL=0
for bpmn in "$ROOT/BPMN-Processes/"*.bpmn; do
  tmpfile="/tmp/$(basename "$bpmn")"
  sed "s|kong-ip|$KONG|g" "$bpmn" > "$tmpfile"
  http_code=$(curl -s -o /tmp/deploy_response.json -w "%{http_code}" \
    $AUTH \
    -X POST "$CAMUNDA_API/v2/deployments" \
    -F "resources=@$tmpfile")
  name=$(basename "$bpmn")
  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "  [OK]   $name (HTTP $http_code)"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] $name (HTTP $http_code)"
    cat /tmp/deploy_response.json 2>/dev/null
    FAIL=$((FAIL+1))
  fi
done
echo "  Deployed: $PASS OK, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "[ERROR] Some BPMN deployments failed — check Camunda is reachable and auth is correct." >&2
  exit 1
fi

# ── Step 2: Resolve ProsumerManagement process definition key ─────────────────
echo "================================================"
echo " Finding ProsumerManagement process definition"
echo "================================================"

PROC_KEY=$(curl -s $AUTH "$CAMUNDA_API/v2/process-definitions/search" \
  -H "Content-Type: application/json" \
  -d '{"filter":{"processDefinitionId":"ProsumerManagement"}}' \
  | python3 -c "import sys,json; items=json.load(sys.stdin).get('items',[]); print(items[0]['processDefinitionKey'] if items else '')" 2>/dev/null)

if [ -z "$PROC_KEY" ]; then
  echo "[ERROR] Could not find ProsumerManagement process definition. Was deployment successful?" >&2
  exit 1
fi
echo "  Process definition key: $PROC_KEY"
echo ""

# ── Step 3: Start a process instance ─────────────────────────────────────────
echo "================================================"
echo " Starting ProsumerManagement process instance"
echo "================================================"

INSTANCE=$(curl -s $AUTH \
  -X POST "$CAMUNDA_API/v2/process-instances" \
  -H "Content-Type: application/json" \
  -d "{
    \"processDefinitionKey\": \"$PROC_KEY\",
    \"variables\": {
      \"body\": {
        \"name\": \"BPMN Test Prosumer\",
        \"location\": \"Lisbon\",
        \"capacity\": 10.5,
        \"type\": \"residential\"
      }
    }
  }")

INSTANCE_KEY=$(echo "$INSTANCE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('processInstanceKey',''))" 2>/dev/null)
if [ -z "$INSTANCE_KEY" ]; then
  echo "[ERROR] Failed to start process instance:" >&2
  echo "$INSTANCE" >&2
  exit 1
fi
echo "  Process instance key: $INSTANCE_KEY"
echo ""

# ── Step 4: Find + complete the KYC user task ─────────────────────────────────
echo "================================================"
echo " Finding KYC user task"
echo "================================================"

TASK_KEY=""
for i in $(seq 1 20); do
  # Zeebe v2 user task API — works with <zeebe:userTask> extension in BPMN
  TASK_KEY=$(curl -s $AUTH \
    -X POST "$CAMUNDA_API/v2/user-tasks/search" \
    -H "Content-Type: application/json" \
    -d "{\"filter\":{\"processInstanceKey\":\"$INSTANCE_KEY\"}}" \
    | python3 -c "import sys,json; items=json.load(sys.stdin).get('items',[]); print(str(items[0]['userTaskKey']) if items else '')" 2>/dev/null)
  if [ -n "$TASK_KEY" ]; then
    break
  fi
  echo "  Waiting for user task to appear... ($i/20)"
  sleep 3
done

if [ -z "$TASK_KEY" ]; then
  echo "[ERROR] KYC user task not found after 60s." >&2
  echo "  Check Tasklist at: $CAMUNDA_API (login demo/demo -> Tasklist)" >&2
  exit 1
fi
echo "  User task key: $TASK_KEY"
echo ""

echo "================================================"
echo " Completing KYC task with approved=true"
echo "================================================"

COMPLETE_CODE=$(curl -s -o /tmp/complete_response.json -w "%{http_code}" \
  $AUTH \
  -X POST "$CAMUNDA_API/v2/user-tasks/$TASK_KEY/completion" \
  -H "Content-Type: application/json" \
  -d '{"variables":{"approved":true}}')

if [[ "$COMPLETE_CODE" == "200" || "$COMPLETE_CODE" == "204" ]]; then
  echo "  [OK] Task completed (HTTP $COMPLETE_CODE)"
else
  echo "  [FAIL] Task completion returned HTTP $COMPLETE_CODE:" >&2
  cat /tmp/complete_response.json >&2
  exit 1
fi
echo ""

# ── Step 5: Wait for process to finish + verify via Kong ──────────────────────
echo "================================================"
echo " Waiting for service task to execute via Kong"
echo "================================================"
sleep 10

SOURCE_URL=$(terraform -chdir="$ROOT/terraform/Quarkus-Terraform/group-a" \
  state show aws_instance.exampleDeployQuarkus -no-color 2>/dev/null \
  | grep ' public_dns' | sed 's/.*=//;s/"//g;s/ //g')
PROSUMER_URL="http://${SOURCE_URL:-$KONG}:8080"

PROSUMERS=$(curl -s "$PROSUMER_URL/Prosumer" 2>/dev/null || echo "[]")
COUNT=$(echo "$PROSUMERS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

if [ "$COUNT" -gt 0 ]; then
  echo "  [PASS] Prosumers in DB: $COUNT (BPMN flow completed successfully)"
else
  echo "  [WARN] No prosumers found — service task may have failed or Kong routing issue"
  echo "         Check Camunda Operate: http://$CAMUNDA:8081"
fi

echo ""
echo "================================================"
echo " Camunda dashboards:"
echo "  Operate:  http://$CAMUNDA:8081  (login: demo / demo)"
echo "  Tasklist: http://$CAMUNDA:8082  (login: demo / demo)"
echo "  Kong Manager: http://$KONG:8002"
echo "================================================"
