pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target server IP', defaultValue: '10.130.0.24')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory', defaultValue: '/opt/webbooks')
        string(name: 'SOURCE_JOB', description: 'Source job name', defaultValue: 'Webbooks-Multibranch/main')
        string(name: 'ARTIFACT_PATH', description: 'Artifact path', defaultValue: 'apps/webbooks/target/webbooks.jar')
    }
    
    environment {
        SERVICE_NAME = 'webbooks'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    // Получаем последний успешный билд
                    def buildNumber = build(job: params.SOURCE_JOB, propagate: false).number
                    
                    // Формируем URL для скачивания
                    def artifactUrl = "${env.JENKINS_URL}job/${params.SOURCE_JOB}/${buildNumber}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Downloading artifact from: ${artifactUrl}"
                    
                    // Скачиваем с использованием API токена
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            curl -sSL -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
                        """
                    }
                    
                    // Проверяем скачивание
                    if (!fileExists('webbooks.jar')) {
                        error("Failed to download artifact from ${artifactUrl}")
                    }
                    
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    // Проверяем существование файла перед деплоем
                    if (!fileExists(env.ACTUAL_ARTIFACT_PATH)) {
                        error("Artifact file not found at ${env.ACTUAL_ARTIFACT_PATH}")
                    }
                    
                    // Используем withCredentials с SSH ключом
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh """
                            echo "Copying artifact to ${params.TARGET_HOST}"
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                            
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} << 'EOF'
                                # Команды выполняются на удаленном сервере
                                sudo systemctl stop $SERVICE_NAME || true
                                sudo cp /tmp/webbooks.jar ${params.DEPLOY_PATH}/webbooks.jar
                                sudo chown webbooks:webbooks ${params.DEPLOY_PATH}/webbooks.jar
                                sudo systemctl start $SERVICE_NAME
                                sleep 5
EOF
                        """
                    }
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
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} << 'EOF'
                            # Проверяем статус сервиса
                            if ! sudo systemctl is-active $SERVICE_NAME; then
                                echo "Service is not running"
                                exit 1
                            fi
                            
                            # Проверяем health endpoint
                            if ! curl -s --connect-timeout 10 http://localhost:8080/actuator/health | grep -q '"status":"UP"'; then
                                echo "Health check failed"
                                exit 1
                            fi
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
                    // Очистка временного файла на удаленном сервере
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
