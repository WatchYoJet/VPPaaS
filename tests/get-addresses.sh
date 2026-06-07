#!/bin/bash
# Sources all service addresses written by Deploy.sh.
# Source this file; it exports all DNS variables for use in test scripts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
ENV_FILE="$ROOT/account1-addresses.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "[get-addresses] ERROR: $ENV_FILE not found — has Deploy.sh been run?" >&2
  return 1
fi

source "$ENV_FILE"

if [ -z "$PROSUMER_DNS" ] || [ -z "$KONG_DNS" ]; then
  echo "[get-addresses] ERROR: addresses incomplete — re-run Deploy.sh" >&2
  return 1
fi

export PROSUMER_DNS UTILITYOPERATOR_DNS TELEMETRY_DNS
export KONG_DNS CAMUNDA_DNS
export ASSETLINK_DNS FLEXIBILITYEVENT_DNS OLLAMA_DNS ENERGYANALYTICS_DNS GRIDBALANCING_DNS
export KAFKA_BROKERS RDS_ENDPOINT KONGA_DNS
