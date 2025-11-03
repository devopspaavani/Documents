withCredentials([
  usernamePassword(credentialsId: 'git_token', usernameVariable: 'GIT_USER', passwordVariable: 'git_token'),
  usernamePassword(credentialsId: 'azure_sp', usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET'),
  string(credentialsId: 'azure_tenant', variable: 'TENANT_ID'),
  string(credentialsId: 'azure_subscription', variable: 'ARM_SUBSCRIPTION_ID')
]) {
  script {
    def buildUrl = "${env.BUILD_URL}"
    def repoName = "${PR_REPO_NAME}"
    def commitSHA = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
    def CON_EXEC = "/data/scripts/azure-terraform-plan.sh \"/data/source\""

    // 🔸 Mark PR check as pending
    sh """
      curl -s -X POST \
        -H "Authorization: token ${git_token}" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/repos/${repoName}/statuses/${commitSHA} \
        -d '{
          "state": "pending",
          "context": "Terraform Plan",
          "description": "Terraform plan running in Jenkins...",
          "target_url": "${buildUrl}"
        }'
    """

    // 🔹 Run inside container with pre & post logic
    containerExec("${CON_NAME}") {
      try {
        sh '''
          echo "========== PRE-STAGE =========="
          echo "Running initial validation..."
          terraform -version || true
        '''

        // 🔹 Main Terraform script
        sh """
          echo "========== MAIN: Terraform Plan =========="
          chmod +x ${CON_EXEC}
          ${CON_EXEC}
        """

        sh '''
          echo "========== POST-STAGE =========="
          echo "Cleaning workspace..."
          rm -rf .terraform || true
          echo "Done ✅"
        '''

        // ✅ Report success to GitHub
        sh """
          curl -s -X POST \
            -H "Authorization: token ${git_token}" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${repoName}/statuses/${commitSHA} \
            -d '{
              "state": "success",
              "context": "Terraform Plan",
              "description": "Terraform plan passed successfully.",
              "target_url": "${buildUrl}"
            }'
        """

      } catch (err) {
        // ❌ Report failure
        sh """
          curl -s -X POST \
            -H "Authorization: token ${git_token}" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${repoName}/statuses/${commitSHA} \
            -d '{
              "state": "failure",
              "context": "Terraform Plan",
              "description": "Terraform plan failed. Check Jenkins logs.",
              "target_url": "${buildUrl}"
            }'
        """
        throw err
      }
    }
  }
}
