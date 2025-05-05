pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target server IP')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory')
        string(name: 'SOURCE_JOB', description: 'Job that triggered this deploy')
        string(name: 'ARTIFACT_PATH', description: 'Path to artifact in source job')
    }
    
    environment {
        SSH_CREDS = credentials('webbooks-ssh-creds')
        SERVICE_NAME = 'webbooks'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    // Скачиваем артефакт напрямую через Jenkins API
                    def buildNumber = build(job: params.SOURCE_JOB, propagate: false).number
                    def artifactUrl = "${JENKINS_URL}job/${params.SOURCE_JOB}/${buildNumber}/artifact/${params.ARTIFACT_PATH}"
                    
                    sh """
                        curl -s -o webbooks.jar -u \$(curl -s '${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)'):\$API_TOKEN '${artifactUrl}'
                    """
                    
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        echo "Copying artifact to ${params.TARGET_HOST}"
                        scp -o StrictHostKeyChecking=no ${env.ACTUAL_ARTIFACT_PATH} ${env.SSH_CREDS_USR}@${params.TARGET_HOST}:/tmp/webbooks.jar
                        
                        ssh -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "
                            sudo systemctl stop ${env.SERVICE_NAME} || true
                            sudo cp /tmp/webbooks.jar ${params.DEPLOY_PATH}/webbooks.jar
                            sudo chown webbooks:webbooks ${params.DEPLOY_PATH}/webbooks.jar
                            sudo systemctl start ${env.SERVICE_NAME}
                            sleep 5
                        "
                    """
                }
            }
        }
        
        stage('Verify') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "
                            sudo systemctl is-active ${env.SERVICE_NAME} && \
                            curl -s --connect-timeout 10 http://localhost:8080/actuator/health | grep -q '\"status\":\"UP\"'
                        "
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
            sshagent([env.SSH_CREDS]) {
                sh """
                    ssh -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "rm -f /tmp/webbooks.jar" || true
                """
            }
        }
    }
}
