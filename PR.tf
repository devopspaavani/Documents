stage('Terraform Plan') {
  steps {
    withCredentials([
      usernamePassword(credentialsId: 'azure_sp', usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET'),
      string(credentialsId: 'azure_tenant', variable: 'TENANT_ID'),
      string(credentialsId: 'azure_subscription', variable: 'ARM_SUBSCRIPTION_ID'),
      string(credentialsId: 'github_pat', variable: 'GITHUB_TOKEN')
    ]) {
      script {
        def buildUrl = "${env.BUILD_URL}"
        def repoName = "${PR_REPO_NAME}"
        def commitSHA = sh(script: "git rev-parse HEAD", returnStdout: true).trim()

        // 🔸 Mark PR check as pending
        sh """
          curl -s -X POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${repoName}/statuses/${commitSHA} \
            -d '{
              "state": "pending",
              "context": "Terraform Plan",
              "description": "Terraform plan running in Jenkins...",
              "target_url": "${buildUrl}"
            }'
        """

        try {
          // 🧩 Run your existing Terraform plan
          sh '''
            chmod +x /data/scripts/az-terraform.sh
            /data/scripts/az-terraform.sh \
              /data/source_repo \
              ${CLIENT_ID} \
              ${CLIENT_SECRET} \
              ${ARM_SUBSCRIPTION_ID} \
              ${TENANT_ID} \
              ${BASE_REPO_NAME} \
              ${PR_NUMBER}
          '''

          // ✅ Mark as success
          sh """
            curl -s -X POST \
              -H "Authorization: token ${GITHUB_TOKEN}" \
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
          // ❌ Mark as failure
          sh """
            curl -s -X POST \
              -H "Authorization: token ${GITHUB_TOKEN}" \
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
}
