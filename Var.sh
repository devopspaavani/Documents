#!/usr/bin/env bash
set -euo pipefail

# --- Input arguments from Jenkins ---
WORKDIR="${1:-/data/source}"          # The cloned PR repo
PIPELINE_NAME="${2:-unknown-pipeline}" # Jenkins pipeline name
PR_REPO_NAME="${3:-unknown-repo}"
PR_NUMBER="${4:-0}"

echo "===================================================="
echo "🔧 AWS Terraform Plan Execution"
echo "----------------------------------------------------"
echo "📂 WORKDIR:         ${WORKDIR}"
echo "🏗️  PIPELINE_NAME:  ${PIPELINE_NAME}"
echo "📦 PR_REPO_NAME:    ${PR_REPO_NAME}"
echo "🔢 PR_NUMBER:       ${PR_NUMBER}"
echo "===================================================="

# --- Locate terraform and vars directories ---
TF_DIR="${WORKDIR}/config/terraform"
VARS_FILE="${WORKDIR}/config/vars/variables.json"

if [[ ! -d "$TF_DIR" ]]; then
  echo "❌ ERROR: Terraform directory not found at ${TF_DIR}"
  exit 1
fi

if [[ ! -f "$VARS_FILE" ]]; then
  echo "⚠️  WARNING: variables.json not found, skipping jq update."
else
  echo "🧩 Updating variables.json with team_name from pipeline..."
  tmp="${WORKDIR}/config/vars/variables_tmp"
  jq -r ". + {\"team_name\":\"${PIPELINE_NAME}\"}" "${VARS_FILE}" > "${tmp}"
  mv "${tmp}" "${VARS_FILE}"
fi

# --- Switch to Terraform directory ---
cd "${TF_DIR}"
echo "📍 Current dir: $(pwd)"

# --- AWS Authentication ---
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

if [[ -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
  echo "❌ ERROR: AWS credentials not set."
  exit 1
fi

echo "🔐 Using AWS region: ${AWS_DEFAULT_REGION}"

# --- Terraform Plan Execution ---
echo "********** Terraform Init **********"
terraform init -upgrade -no-color

echo "********** Terraform FMT **********"
terraform fmt -check -no-color

echo "********** Terraform Validate **********"
terraform validate -no-color

echo "********** Terraform Plan **********"
terraform plan \
  -input=false \
  -no-color \
  -var-file="${WORKDIR}/config/vars/variables.json" \
  -out=tfplan.out

echo "✅ Terraform plan completed successfully"
