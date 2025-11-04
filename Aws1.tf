stage('Terraform Plan (Auto Cloud Detection)') {
  steps {
    script {

      // --- Detect which repo type triggered this PR ---
      def repoName = env.BASE_REPO_NAME?.toLowerCase() ?: ""
      def cloudProvider = repoName.contains("azure") ? "azure" :
                          repoName.contains("aws")   ? "aws"   :
                          "unknown"

      if (cloudProvider == "unknown") {
        error("❌ Could not determine cloud provider from repo name: ${repoName}")
      }

      echo "☁️ Detected cloud provider: ${cloudProvider.toUpperCase()}"
      echo "📦 Repository: ${repoName}"
      echo "🔢 PR Number: ${env.PR_NUMBER}"

      // --- Select correct script path ---
      def scriptPath = (cloudProvider == "azure") ?
        "/data/Scripts/azure-terraform-plan.sh" :
        "/data/Scripts/aws-terraform-plan.sh"

      // --- Select container name ---
      def CON_NAME = (cloudProvider == "azure") ? "terraform-azure" : "terraform-aws"

      // --- Inject credentials dynamically based on provider ---
      if (cloudProvider == "azure") {
        withCredentials([
          usernamePassword(credentialsId: 'azure_spn', usernameVariable: 'ARM_CLIENT_ID', passwordVariable: 'ARM_CLIENT_SECRET'),
          string(credentialsId: 'azure_tenant', variable: 'ARM_TENANT_ID'),
          string(credentialsId: 'azure_subscription', variable: 'ARM_SUBSCRIPTION_ID')
        ]) {
          runTerraformPlan(CON_NAME, scriptPath, cloudProvider)
        }
      } else {
        withCredentials([
          usernamePassword(credentialsId: 'aws_keys', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY'),
          string(credentialsId: 'aws_region', variable: 'AWS_DEFAULT_REGION')
        ]) {
          runTerraformPlan(CON_NAME, scriptPath, cloudProvider)
        }
      }
    }
  }
}
