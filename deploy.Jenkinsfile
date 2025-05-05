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
                    def buildNumber = build(job: params.SOURCE_JOB, propagate: false).number
                    def artifactUrl = "${env.JENKINS_URL}job/${params.SOURCE_JOB}/${buildNumber}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Downloading artifact from: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            curl -sSL -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
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
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        // 1. Копируем файл на сервер
                        sh """
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                        """
                        
                        // 2. Выполняем команды развертывания через отдельный скрипт
                        def deployScript = '''
                            #!/bin/bash
                            set -e
                            
                            # Проверяем существование файла
                            if [ ! -f "/tmp/webbooks.jar" ]; then
                                echo "Error: Artifact not found on target server"
                                exit 1
                            fi
                            
                            # Останавливаем сервис
                            sudo systemctl stop webbooks || true
                            
                            # Копируем новый артефакт
                            sudo cp /tmp/webbooks.jar /opt/webbooks/webbooks.jar
                            sudo chown webbooks:webbooks /opt/webbooks/webbooks.jar
                            
                            # Запускаем сервис
                            sudo systemctl start webbooks
                            sleep 5
                            
                            # Проверяем статус
                            if ! sudo systemctl is-active webbooks; then
                                echo "Error: Service failed to start"
                                exit 1
                            fi
                        '''
                        
                        // Сохраняем скрипт локально
                        writeFile file: 'deploy.sh', text: deployScript
                        
                        // Копируем и выполняем скрипт на удаленном сервере
                        sh """
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" deploy.sh $SSH_USER@${params.TARGET_HOST}:/tmp/
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                chmod +x /tmp/deploy.sh
                                /tmp/deploy.sh
                                rm -f /tmp/deploy.sh
                            '
                        """
                    }
                }
            }
        }
        
        stage('Verify') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                # Проверяем health endpoint
                                if ! curl -s --connect-timeout 10 http://localhost:8080/actuator/health | grep -q \'"status":"UP"\'; then
                                    echo "Error: Health check failed"
                                    exit 1
                                fi
                                echo "Deployment verification successful"
                            '
                        """
                    }
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
                    echo "Warning: Failed to clean up temporary file: ${e}"
                }
            }
        }
    }
}
