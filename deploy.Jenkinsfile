pipeline {
    agent any
    
    environment {
        DEPLOY_PATH = '/opt/webbooks'
        SERVICE_NAME = 'webbooks'
    }
    
    stages {
        stage('Deploy') {
            steps {
                script {
                    try {
                        withCredentials([sshUserPrivateKey(
                            credentialsId: 'webbooks-ssh-creds',
                            keyFileVariable: 'SSH_KEY',
                            usernameVariable: 'SSH_USER'
                        )]) {
                            sh """
                                echo "Starting deployment..."
                                scp -o StrictHostKeyChecking=no -i "$SSH_KEY" webbooks.jar ${SSH_USER}@10.130.0.24:${DEPLOY_PATH}/
                                ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ${SSH_USER}@10.130.0.24 "
                                    sudo systemctl stop ${SERVICE_NAME} || true
                                    sudo systemctl start ${SERVICE_NAME}
                                "
                            """
                        }
                    } catch (Exception e) {
                        error "Deployment failed: ${e.getMessage()}"
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo 'Deployment completed successfully'
        }
        failure {
            echo 'Deployment failed'
        }
    }
}
