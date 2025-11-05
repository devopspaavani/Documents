// ----------------------------
// Local Subscription Mapping
// ----------------------------
def AZURE_SUB_AUTOMATED = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
def AZURE_SUB_SANDBOX   = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
def AZURE_SUB_REAP      = "cccccccc-cccc-cccc-cccc-cccccccccccc"  // if applicable


pipeline {
  agent any

  stages {

    stage('Detect Repo & Provider') {
      steps {
        script {

          repoName = (env.PR_REPO_NAME ?: "").toLowerCase()

          cloudProvider = repoName.contains("azure") ? "azure" :
                          repoName.contains("aws")   ? "aws"   : "unknown"

          if (cloudProvider == "unknown") {
            error "❌ Unable to determine cloud provider from repo name: ${repoName}"
          }

          envType = repoName.contains("automated") ? "automated" :
                    repoName.contains("sandbox")   ? "sandbox"   :
                    repoName.contains("reap")      ? "reap"      : "default"

          echo """
          ============================
          Cloud Provider : ${cloudProvider.toUpperCase()}
          Environment    : ${envType.toUpperCase()}
          Repo           : ${repoName}
          ============================
          """
        }
      }
    }


    stage('Run Terraform Plan') {
      steps {
        script {

          // Select script
          def scriptFile = (cloudProvider == "azure")
              ? "/data/Scripts/azure-terraform-plan.sh"
              : "/data/Scripts/aws-terraform-plan.sh"

          // Select Subscription ID
          def subscriptionId = ""
          if (cloudProvider == "azure") {
            subscriptionId = (
              envType == "automated" ? AZURE_SUB_AUTOMATED :
              envType == "sandbox"   ? AZURE_SUB_SANDBOX   :
              envType == "reap"      ? AZURE_SUB_REAP      :
              ""
            )?.trim()

            if (!subscriptionId) {
              error "❌ Subscription ID missing for envType=${envType}"
            }

            echo "🔑 Using Subscription: ${subscriptionId.take(8)}********"
          }

          // Build execution command
          def CON_EXEC = ""
          if (cloudProvider == "azure") {
            CON_EXEC = "${scriptFile} " +
                        "\"/data/source\" " +
                        "\"${ARM_CLIENT_ID}\" " +
                        "\"${ARM_CLIENT_SECRET}\" " +
                        "\"${subscriptionId}\" " +
                        "\"${ARM_TENANT_ID}\" " +
                        "\"${PR_REPO_NAME}\" " +
                        "\"${PR_NUMBER}\""
          }
          else if (cloudProvider == "aws") {
            CON_EXEC = "${scriptFile} " +
                        "\"/data/source\" " +
                        "\"${AWS_ACCESS_KEY_ID}\" " +
                        "\"${AWS_SECRET_ACCESS_KEY}\" " +
                        "\"${PR_REPO_NAME}\" " +
                        "\"${PR_NUMBER}\""
          }

          echo "🚀 Running Terraform Plan: ${scriptFile}"
          containerExec("${CON_NAME}", "${CON_EXEC}")
        }
      }
    }
  }

  post {
    success {
      script {
        updateGitHubStatus("success", "Terraform plan succeeded — click Details to view plan in Jenkins")
      }
    }
    failure {
      script {
        updateGitHubStatus("failure", "Terraform plan failed — check Jenkins logs for details")
      }
    }
  }
}

--========================
#!/bin/bash
set -euo pipefail

WORKDIR="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
SUBSCRIPTION_ID="$4"
TENANT_ID="$5"
REPO_NAME="$6"
PR_NUMBER="$7"

echo "🌩 Azure Terraform Plan for $REPO_NAME (PR #$PR_NUMBER)"
echo "🔑 Subscription: $SUBSCRIPTION_ID"
echo "🏢 Tenant: $TENANT_ID"

export ARM_CLIENT_ID="$CLIENT_ID"
export ARM_CLIENT_SECRET="$CLIENT_SECRET"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_TENANT_ID="$TENANT_ID"

az login --service-principal -u "$CLIENT_ID" -p "$CLIENT_SECRET" --tenant "$TENANT_ID" >/dev/null
az account set --subscription "$SUBSCRIPTION_ID"

TF_DIR="${WORKDIR}/config/terraform"
cd "$TF_DIR"

terraform init -upgrade -no-color
terraform fmt -no-color
terraform validate -no-color
terraform plan -no-color | tee /data/source/plan.out
