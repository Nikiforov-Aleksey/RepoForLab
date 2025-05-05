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
                    // Получаем номер последнего успешного билда исходного job
                    def buildNumber = build(job: params.SOURCE_JOB, propagate: false).number
                    
                    // Формируем правильный URL для скачивания артефакта
                    def artifactUrl = "${env.JENKINS_URL}job/${params.SOURCE_JOB}/${buildNumber}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Downloading artifact from: ${artifactUrl}"
                    
                    // Скачиваем артефакт с использованием credentials
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            curl -sSL -u ${JENKINS_USER}:${JENKINS_TOKEN} -o webbooks.jar "${artifactUrl}"
                        """
                    }
                    
                    // Проверяем, что файл скачан
                    if (!fileExists('webbooks.jar')) {
                        error("Failed to download artifact from ${artifactUrl}")
                    }
                    
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        stage('Deploy') {
            steps {
                // Используем withCredentials вместо sshagent
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'webbooks-ssh-creds',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh """
                        echo "Copying artifact to ${params.TARGET_HOST}"
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ${env.ACTUAL_ARTIFACT_PATH} ${SSH_USER}@${params.TARGET_HOST}:/tmp/webbooks.jar
                        
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${params.TARGET_HOST} "
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
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'webbooks-ssh-creds',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${params.TARGET_HOST} "
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
            script {
                try {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${params.TARGET_HOST} "rm -f /tmp/webbooks.jar" || true
                        """
                    }
                } catch (e) {
                    echo "Failed to clean up temporary file: ${e}"
                }
            }
        }
    }
}
