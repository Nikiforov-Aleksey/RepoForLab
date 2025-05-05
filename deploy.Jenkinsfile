pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target server IP')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory')
        string(name: 'SOURCE_JOB', description: 'Job that triggered this deploy')
        string(name: 'ARTIFACT_PATH', description: 'Path to artifact in source job')
    }
    
    environment {
        SERVICE_NAME = 'webbooks'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    def buildNumber = build(job: params.SOURCE_JOB, propagate: false).number
                    def artifactUrl = "${env.JENKINS_URL}job/${params.SOURCE_JOB}/${buildNumber}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Downloading artifact from: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            curl -sSL -u $JENKINS_USER:$JENKINS_TOKEN -o webbooks.jar "${artifactUrl}"
                        """
                    }
                    
                    if (!fileExists('webbooks.jar')) {
                        error("Failed to download artifact from ${artifactUrl}")
                    }
                    
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'webbooks-ssh-creds',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER',
                    passphraseVariable: 'SSH_PASSPHRASE'
                )]) {
                    sh """
                        echo "Copying artifact to ${params.TARGET_HOST}"
                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                        
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} << 'EOF'
                            echo $SSH_PASSPHRASE | sudo -S systemctl stop $SERVICE_NAME || true
                            echo $SSH_PASSPHRASE | sudo -S cp /tmp/webbooks.jar ${params.DEPLOY_PATH}/webbooks.jar
                            echo $SSH_PASSPHRASE | sudo -S chown webbooks:webbooks ${params.DEPLOY_PATH}/webbooks.jar
                            echo $SSH_PASSPHRASE | sudo -S systemctl start $SERVICE_NAME
                            sleep 5
EOF
                    """
                }
            }
        }
        
        stage('Verify') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'webbooks-ssh-creds',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER',
                    passphraseVariable: 'SSH_PASSPHRASE'
                )]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} << 'EOF'
                            echo $SSH_PASSPHRASE | sudo -S systemctl is-active $SERVICE_NAME
                            curl -s --connect-timeout 10 http://localhost:8080/actuator/health | grep -q '"status":"UP"'
EOF
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
            script {
                try {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} "rm -f /tmp/webbooks.jar" || true
                        """
                    }
                } catch (e) {
                    echo "Failed to clean up temporary file: ${e}"
                }
            }
        }
    }
}
