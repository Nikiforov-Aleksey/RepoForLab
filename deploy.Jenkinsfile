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
                    
                    // Используем copyArtifacts plugin
                    step([$class: 'CopyArtifact',
                        projectName: params.SOURCE_JOB,
                        filter: params.ARTIFACT_PATH,
                        selector: [$class: 'SpecificBuildSelector', buildNumber: buildInfo.number],
                        target: '.'
                    ])
                    
                    // Проверяем что файл скопирован
                    if (!fileExists('webbooks.jar')) {
                        error "Артефакт webbooks.jar не был скопирован"
                    }
                    
                    // Проверяем валидность JAR
                    sh '''
                        echo "Проверка артефакта:"
                        ls -la webbooks.jar
                        file webbooks.jar
                        if ! jar -tf webbooks.jar >/dev/null 2>&1; then
                            echo "ERROR: Скачанный файл не является валидным JAR-архивом"
                            exit 1
                        fi
                    '''
                    
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
                                # Останавливаем сервис
                                sudo systemctl stop webbooks || true
                                
                                # Делаем бэкап
                                [ -f "${params.DEPLOY_PATH}/webbooks.jar" ] && sudo cp "${params.DEPLOY_PATH}/webbooks.jar" "${params.DEPLOY_PATH}/webbooks.jar.bak"
                                
                                # Копируем новый артефакт
                                sudo cp /tmp/webbooks.jar "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chown webbooks:webbooks "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chmod 500 "${params.DEPLOY_PATH}/webbooks.jar"
                                
                                # Перезагружаем systemd
                                sudo systemctl daemon-reload
                                
                                # Запускаем сервис
                                sudo systemctl start webbooks
                                
                                # Проверяем статус
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
