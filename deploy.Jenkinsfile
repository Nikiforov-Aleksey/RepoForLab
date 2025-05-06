pipeline {
    agent any
    
    environment {
        // Явно задаем имя сервиса и пользователя
        SERVICE_NAME = 'webbooks'
        DEPLOY_USER = 'webbooks'
        DEPLOY_PATH = '/opt/webbooks'
        JAR_NAME = 'webbooks.jar'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    // Ваш существующий код копирования артефактов
                    // ...
                    
                    // Убедитесь что env.ACTUAL_ARTIFACT_PATH установлен
                    env.ACTUAL_ARTIFACT_PATH = 'DigitalLibrary-0.0.1-SNAPSHOT.jar'
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
                        sh """
                            echo "=== Начало деплоя ==="
                            echo "Копируем артефакт на сервер..."
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "${env.ACTUAL_ARTIFACT_PATH}" ${SSH_USER}@${params.TARGET_HOST}:/tmp/${env.JAR_NAME}
                            
                            echo "Выполняем деплой..."
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ${SSH_USER}@${params.TARGET_HOST} '
                                set -e
                                echo "1. Проверяем/создаем каталог..."
                                sudo mkdir -p ${env.DEPLOY_PATH}
                                sudo chown ${env.DEPLOY_USER}:${env.DEPLOY_USER} ${env.DEPLOY_PATH}
                                
                                echo "2. Останавливаем сервис..."
                                sudo systemctl stop ${env.SERVICE_NAME} || true
                                
                                echo "3. Создаем бэкап..."
                                [ -f "${env.DEPLOY_PATH}/${env.JAR_NAME}" ] && sudo cp "${env.DEPLOY_PATH}/${env.JAR_NAME}" "${env.DEPLOY_PATH}/${env.JAR_NAME}.bak.\$(date +%s)"
                                
                                echo "4. Копируем новый артефакт..."
                                sudo cp /tmp/${env.JAR_NAME} "${env.DEPLOY_PATH}/${env.JAR_NAME}"
                                sudo chown ${env.DEPLOY_USER}:${env.DEPLOY_USER} "${env.DEPLOY_PATH}/${env.JAR_NAME}"
                                sudo chmod 500 "${env.DEPLOY_PATH}/${env.JAR_NAME}"
                                
                                echo "5. Проверяем файл..."
                                ls -la "${env.DEPLOY_PATH}/${env.JAR_NAME}"
                                file "${env.DEPLOY_PATH}/${env.JAR_NAME}"
                                
                                echo "6. Перезагружаем systemd..."
                                sudo systemctl daemon-reload
                                
                                echo "7. Запускаем сервис..."
                                sudo systemctl start ${env.SERVICE_NAME}
                                
                                echo "8. Проверяем статус..."
                                sleep 5
                                sudo systemctl is-active ${env.SERVICE_NAME} || {
                                    echo "ERROR: Сервис не запустился"
                                    sudo journalctl -u ${env.SERVICE_NAME} -n 50 --no-pager
                                    exit 1
                                }
                            '
                        """
                    }
                }
            }
        }
    }
    
    post {
        failure {
            script {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'webbooks-ssh-creds',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ${SSH_USER}@${params.TARGET_HOST} '
                            echo "=== Debug Info ==="
                            echo "Service status:"
                            sudo systemctl status ${env.SERVICE_NAME} --no-pager || true
                            echo "Journal logs:"
                            sudo journalctl -u ${env.SERVICE_NAME} -n 100 --no-pager || true
                            echo "Jar file info:"
                            ls -la "${env.DEPLOY_PATH}/${env.JAR_NAME}"
                            file "${env.DEPLOY_PATH}/${env.JAR_NAME}"
                        '
                    """
                }
            }
        }
    }
}
