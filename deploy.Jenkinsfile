pipeline {
    agent any
    
    parameters {
        string(name: 'SOURCE_BUILD_NUMBER', description: 'Номер сборки с артефактами')
    }
    
    environment {
        ARTIFACT_NAME = 'webbooks.jar'
        DEPLOY_PATH = '/opt/webbooks'
        SERVICE_NAME = 'webbooks'
    }
    
    stages {
        stage('Prepare') {
            steps {
                script {
                    // Получаем артефакты из сборки
                    copyArtifacts(
                        projectName: 'Webbooks-Multibranch/main',
                        selector: specific(params.SOURCE_BUILD_NUMBER),
                        filter: '**/*.jar',
                        target: '.',
                        flatten: true
                    )
                    
                    // Проверяем что файл существует
                    if (!fileExists(env.ARTIFACT_NAME)) {
                        error "Файл ${env.ARTIFACT_NAME} не найден"
                    }
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
                            echo "Копируем ${env.ARTIFACT_NAME} на сервер..."
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" ${env.ARTIFACT_NAME} ${SSH_USER}@10.130.0.24:/tmp/${env.ARTIFACT_NAME}
                            
                            echo "Выполняем деплой..."
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ${SSH_USER}@10.130.0.24 '
                                set -e
                                echo "1. Останавливаем сервис..."
                                sudo systemctl stop ${env.SERVICE_NAME} || true
                                
                                echo "2. Создаем бэкап..."
                                [ -f "${env.DEPLOY_PATH}/${env.ARTIFACT_NAME}" ] && \\
                                    sudo cp "${env.DEPLOY_PATH}/${env.ARTIFACT_NAME}" "${env.DEPLOY_PATH}/${env.ARTIFACT_NAME}.bak.\$(date +%s)"
                                
                                echo "3. Копируем новый артефакт..."
                                sudo mkdir -p ${env.DEPLOY_PATH}
                                sudo cp /tmp/${env.ARTIFACT_NAME} "${env.DEPLOY_PATH}/"
                                sudo chown ${env.SERVICE_NAME}:${env.SERVICE_NAME} "${env.DEPLOY_PATH}/${env.ARTIFACT_NAME}"
                                sudo chmod 750 "${env.DEPLOY_PATH}/${env.ARTIFACT_NAME}"
                                
                                echo "4. Перезагружаем systemd..."
                                sudo systemctl daemon-reload
                                
                                echo "5. Запускаем сервис..."
                                sudo systemctl start ${env.SERVICE_NAME}
                                
                                echo "6. Проверяем статус..."
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
            echo 'Деплой завершился с ошибкой'
        }
        success {
            echo 'Деплой успешно завершен'
        }
    }
}
