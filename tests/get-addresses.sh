#!/bin/bash
# Reads live EC2 addresses from Terraform state.
# Source this file; it exports GROUP_A, GROUP_B, GROUP_C, OLLAMA, KONG.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

_dns() {
  terraform -chdir="$ROOT/$1" state show "$2" -no-color 2>/dev/null \
    | grep ' public_dns' \
    | sed 's/.*=//;s/"//g;s/ //g'
}

GROUP_A=$(_dns "terraform/Quarkus-Terraform/group-a" "aws_instance.exampleDeployQuarkus")
GROUP_B=$(_dns "terraform/Quarkus-Terraform/group-b" "aws_instance.exampleDeployQuarkus")
GROUP_C=$(_dns "terraform/Quarkus-Terraform/group-c" "aws_instance.exampleDeployQuarkus")
OLLAMA=$(_dns "terraform/Ollama-Terraform"           "aws_instance.ollamaInstance")
KONG=$(_dns   "terraform/KongTerraform"              "aws_instance.exampleInstallKong")

if [ -z "$GROUP_A" ] || [ -z "$GROUP_B" ] || [ -z "$GROUP_C" ]; then
  echo "[get-addresses] ERROR: one or more group addresses are empty — has DeploymentSprint2.sh been run?" >&2
  exit 1
fi

export GROUP_A GROUP_B GROUP_C OLLAMA KONG
