pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', defaultValue: '10.130.0.24', description: 'Target server IP')
        string(name: 'DEPLOY_PATH', defaultValue: '/opt/webbooks', description: 'Deployment directory')
        string(name: 'SOURCE_JOB', defaultValue: 'Webbooks-Multibranch/main', description: 'Source job name')
        string(name: 'ARTIFACT_PATH', defaultValue: '**/webbooks.jar', description: 'Artifact path pattern')
    }
    
    environment {
        SERVICE_NAME = 'webbooks'
        JENKINS_URL = 'http://158.160.184.242:8080/'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    // Получаем информацию о сборке
                    def buildInfo = build(
                        job: params.SOURCE_JOB,
                        propagate: false,
                        wait: true,
                        parameters: []
                    )
                    
                    if (buildInfo.result != 'SUCCESS') {
                        error "Сборка ${params.SOURCE_JOB} завершилась со статусом ${buildInfo.result}"
                    }
                    
                    // Альтернативный способ получения артефакта без использования Jenkins API
                    def artifactUrl = "${env.JENKINS_URL}job/${params.SOURCE_JOB.replace('/', '/job/')}/${buildInfo.number}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Скачиваем артефакт по шаблону: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            # Скачиваем артефакт
                            curl -v -f -L -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
                            
                            # Проверяем что файл скачан
                            if [ ! -f "webbooks.jar" ]; then
                                echo "ERROR: Файл артефакта не был скачан"
                                exit 1
                            fi
                            
                            # Проверяем что это действительно JAR
                            if ! jar -tf webbooks.jar >/dev/null 2>&1; then
                                echo "ERROR: Скачанный файл не является JAR-архивом"
                                echo "Тип файла:"
                                file webbooks.jar
                                exit 1
                            fi
                            
                            echo "Артефакт успешно скачан и проверен"
                        """
                    }
                    
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        stage('Deploy') {
            when {
                expression { env.ACTUAL_ARTIFACT_PATH != null }
            }
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh """
                            echo "Копируем артефакт на сервер..."
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                            
                            echo "Выполняем деплой..."
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                sudo systemctl stop webbooks || true
                                [ -f "${params.DEPLOY_PATH}/webbooks.jar" ] && sudo cp "${params.DEPLOY_PATH}/webbooks.jar" "${params.DEPLOY_PATH}/webbooks.jar.bak"
                                sudo cp /tmp/webbooks.jar "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chown webbooks:webbooks "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chmod 500 "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo systemctl daemon-reload
                                sudo systemctl start webbooks
                                sleep 5
                                if [ "\$(sudo systemctl is-active webbooks)" != "active" ]; then
                                    echo "ERROR: Не удалось запустить сервис"
                                    sudo journalctl -u webbooks -n 50 --no-pager
                                    exit 1
                                fi
                                echo "Сервис успешно запущен"
                            '
                        """
                    }
                }
            }
        }
        
        stage('Verify') {
            when {
                expression { env.ACTUAL_ARTIFACT_PATH != null }
            }
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh """
                            echo "Проверяем работоспособность сервиса..."
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                for i in {1..10}; do
                                    if curl -s --connect-timeout 5 http://localhost:8080/actuator/health | grep -q \'"status":"UP"\'; then
                                        echo "Health check пройден"
                                        exit 0
                                    fi
                                    sleep 5
                                done
                                echo "ERROR: Health check не пройден после 50 секунд ожидания"
                                sudo journalctl -u webbooks -n 50 --no-pager
                                exit 1
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
                    echo "Warning: Не удалось очистить временные файлы: ${e}"
                }
            }
        }
        failure {
            script {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'webbooks-ssh-creds',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} "
                            echo '=== Статус сервиса Webbooks ==='
                            sudo systemctl status webbooks --no-pager || true
                            echo '=== Последние логи ==='
                            sudo journalctl -u webbooks -n 50 --no-pager || true
                        "
                    """
                }
            }
        }
    }
}
