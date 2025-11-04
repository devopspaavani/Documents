stage('Terraform Plan') {
  steps {
    script {
      // --- Detect repository name & environment ---
      def repoName = env.PR_REPO_NAME?.toLowerCase() ?: ""
      def cloudProvider = repoName.contains("azure") ? "azure" :
                          repoName.contains("aws")   ? "aws"   : "unknown"

      if (cloudProvider == "unknown") {
        error("❌ Could not determine cloud provider from repo name: ${repoName}")
      }

      def envType = repoName.contains("automated") ? "automated" :
                    repoName.contains("sandbox")   ? "sandbox"   : "default"

      echo """
      ==============================================
      ☁️  Terraform Plan Execution
      ----------------------------------------------
      📦 Repo: ${repoName}
      🌩️ Cloud Provider: ${cloudProvider.toUpperCase()}
      🏗️ Environment: ${envType.toUpperCase()}
      ==============================================
      """

      // --- Choose the right .sh script ---
      def scriptFile = ""
      if (cloudProvider == "azure" && envType == "automated") {
        scriptFile = "/data/Scripts/azure-automated-plan.sh"
      } else if (cloudProvider == "azure" && envType == "sandbox") {
        scriptFile = "/data/Scripts/azure-sandbox-plan.sh"
      } else if (cloudProvider == "aws") {
        scriptFile = "/data/Scripts/aws-plan.sh"
      } else {
        error("❌ Unsupported combination: ${cloudProvider} / ${envType}")
      }

      echo "🔧 Selected Script: ${scriptFile}"

      // --- Build execution command dynamically ---
      def CON_EXEC = ""
      if (cloudProvider == "azure") {
        CON_EXEC = """"${scriptFile}" \
          "/data/source" \
          "${ARM_CLIENT_ID}" \
          "${ARM_CLIENT_SECRET}" \
          "${ARM_TENANT_ID}" \
          "${BASE_REPO_NAME}" \
          "${PR_NUMBER}"
        """
      } else if (cloudProvider == "aws") {
        CON_EXEC = """"${scriptFile}" \
          "/data/source" \
          "${AWS_ACCESS_KEY_ID}" \
          "${AWS_SECRET_ACCESS_KEY}" \
          "${AWS_DEFAULT_REGION}" \
          "${BASE_REPO_NAME}" \
          "${PR_NUMBER}"
        """
      }

      // --- Execute inside container ---
      echo "🐳 Running ${cloudProvider.toUpperCase()} Terraform Plan inside container..."
      containerExec("${CON_NAME}", "${CON_EXEC}")
    }
  }
}
