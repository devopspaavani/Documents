// --- Detect Cloud Provider Automatically ---
// Option 1: Based on repo naming convention
def cloudProvider = ""
if (env.BASE_REPO_NAME?.toLowerCase().contains("azure")) {
    cloudProvider = "azure"
} else if (env.BASE_REPO_NAME?.toLowerCase().contains("aws")) {
    cloudProvider = "aws"
} else {
    error("❌ Unable to determine cloud provider from repo name: ${env.BASE_REPO_NAME}")
}

// --- Container Name ---
// You can use separate images for each provider, or one multi-cloud container
def CON_NAME = (cloudProvider == "azure") ? "terraform-azure" : "terraform-aws"

// --- Script Path ---
// Different plan scripts for Azure and AWS
def scriptPath = (cloudProvider == "azure")
    ? "/data/Scripts/azure-terraform-plan.sh"
    : "/data/Scripts/aws-terraform-plan.sh"

// --- Inject Credentials Dynamically ---
def CON_EXEC = """
  echo "☁️ Cloud Provider: ${cloudProvider.toUpperCase()}"
  echo "▶️ Running Terraform plan script: ${scriptPath}"

  chmod +x ${scriptPath}

  ${scriptPath} \
    "/data/source" \
    "${ARM_CLIENT_ID ?: AWS_ACCESS_KEY_ID}" \
    "${ARM_CLIENT_SECRET ?: AWS_SECRET_ACCESS_KEY}" \
    "${ARM_ACCESS_KEY ?: AWS_DEFAULT_REGION}" \
    "${BASE_REPO_NAME}" \
    "${PR_NUMBER}"

  PLAN_EXIT_CODE=\$?
  if [ \$PLAN_EXIT_CODE -ne 0 ]; then
    echo "❌ Terraform plan failed for ${cloudProvider.toUpperCase()} with exit code \$PLAN_EXIT_CODE"
    exit \$PLAN_EXIT_CODE
  else
    echo "✅ Terraform plan completed successfully for ${cloudProvider.toUpperCase()}"
  fi
"""

// --- Execute Inside the Correct Container ---
containerExec("${CON_NAME}") {
  sh """
    echo "🚀 Executing Terraform plan inside ${CON_NAME} container"
    ${CON_EXEC}
  """
}
