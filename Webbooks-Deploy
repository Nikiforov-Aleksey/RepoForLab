pipeline {
    agent any
    
    parameters {
        string(name: 'ARTIFACT_PATH', description: 'Path to JAR file')
        string(name: 'TARGET_HOST', description: 'Target server IP')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory')
    }
    
    environment {
        SSH_CREDS = credentials('webbooks-ssh-creds')
    }
    
    stages {
        stage('Copy Artifact') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        scp -o StrictHostKeyChecking=no ${params.ARTIFACT_PATH} ${env.SSH_CREDS_USR}@${params.TARGET_HOST}:/tmp/webbooks.jar
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "
                            sudo systemctl stop webbooks || true
                            sudo cp /tmp/webbooks.jar ${params.DEPLOY_PATH}/webbooks.jar
                            sudo chown webbooks:webbooks ${params.DEPLOY_PATH}/webbooks.jar
                            sudo systemctl start webbooks
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
                            sudo systemctl is-active webbooks && \
                            curl -s http://localhost:8080/actuator/health | grep -q '\"status\":\"UP\"'
                        "
                    """
                }
            }
        }
    }
    
    post {
        failure {
            emailext body: "Деплой ${env.JOB_NAME} #${env.BUILD_NUMBER} завершился неудачно",
                    subject: "FAILED: ${env.JOB_NAME}",
                    to: 'dev-team@example.com'
        }
    }
}
