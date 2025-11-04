success {
    echo "Terraform plan completed successfully."

    script {
        // ✅ Build a guaranteed valid HTTPS link for "Details"
        def jenkinsBase = env.JENKINS_URL ?: "https://jenkins.abc.com"
        def jobPath = env.JOB_NAME ? env.JOB_NAME.replaceAll('/', '/job/') : "job/pr-check"
        def targetUrl = "${jenkinsBase}/job/${jobPath}/${env.BUILD_NUMBER ?: 'latest'}/"

        echo "Resolved Target URL: ${targetUrl}"

        withCredentials([usernamePassword(
            credentialsId: 'git_token',
            usernameVariable: 'GIT_USERNAME',
            passwordVariable: 'GIT_PASSWORD'
        )]) {
            sh """
              curl -s -u "${GIT_USERNAME}:${GIT_PASSWORD}" \
                -H "Accept: application/vnd.github.v3+json" \
                -X POST "${GIT_API_URL}/repos/${PR_REPO_FULL_NAME}/statuses/${PR_SHA}" \
                -d '{
                  "state": "success",
                  "target_url": "${targetUrl}",
                  "description": "Terraform plan succeeded — click Details to view the plan in Jenkins",
                  "context": "Terraform Plan"
                }'
            """
        }
    }
}
