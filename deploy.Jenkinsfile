pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target server IP', defaultValue: '10.130.0.24')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory', defaultValue: '/opt/webbooks')
        string(name: 'SOURCE_JOB', description: 'Source job name', defaultValue: 'Webbooks-Multibranch/main')
        string(name: 'SOURCE_BUILD_NUMBER', description: 'Source build number')  // Добавлен новый параметр
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
                    // Получаем информацию о сборке (если номер не передан)
                    def buildInfo = null
                    if (!params.SOURCE_BUILD_NUMBER) {
                        buildInfo = build(
                            job: params.SOURCE_JOB,
                            propagate: false,
                            wait: true,
                            parameters: []
                        )
                        
                        if (buildInfo.result != 'SUCCESS') {
                            error "Сборка ${params.SOURCE_JOB} завершилась со статусом ${buildInfo.result}"
                        }
                    }
                    
                    // Используем copyArtifacts plugin с явным преобразованием в строку
                    step([
                        $class: 'CopyArtifact',
                        projectName: params.SOURCE_JOB,
                        filter: params.ARTIFACT_PATH,
                        selector: [
                            $class: 'SpecificBuildSelector', 
                            buildNumber: params.SOURCE_BUILD_NUMBER ?: buildInfo.number.toString()  // Явное преобразование в строку
                        ],
                        target: '.'
                    ])
                    
                    // Проверяем что файл скопирован
                    if (!fileExists('webbooks.jar')) {
                        error "Артефакт webbooks.jar не был скопирован"
                    }
                    
                    // Расширенная проверка валидности JAR
                    sh '''
                        echo "=== Проверка артефакта ==="
                        echo "Размер файла:"
                        du -h webbooks.jar
                        echo "Информация о файле:"
                        file webbooks.jar
                        echo "Проверка структуры JAR:"
                        if ! jar -tf webbooks.jar >/dev/null 2>&1; then
                            echo "ERROR: Скачанный файл не является валидным JAR-архивом"
                            echo "Содержимое файла (первые 100 байт):"
                            hexdump -C -n 100 webbooks.jar
                            exit 1
                        fi
                        echo "Проверка наличия основных классов:"
                        if ! jar -tf webbooks.jar | grep -q 'BOOT-INF/classes'; then
                            echo "WARNING: В JAR-файле отсутствуют ожидаемые классы"
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
                            echo "=== Начало деплоя ==="
                            echo "Копируем артефакт на сервер..."
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                            
                            echo "Проверяем файл на сервере перед деплоем..."
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                # Проверяем скопированный файл
                                if [ ! -f "/tmp/webbooks.jar" ]; then
                                    echo "ERROR: Файл не был скопирован на сервер"
                                    exit 1
                                fi
                                
                                echo "Размер файла:"
                                du -h /tmp/webbooks.jar
                                echo "Проверка JAR:"
                                if ! jar -tf /tmp/webbooks.jar >/dev/null 2>&1; then
                                    echo "ERROR: Файл на сервере поврежден"
                                    exit 1
                                fi
                            '
                            
                            echo "Выполняем деплой..."
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                set -e  # Прерывать при ошибках
                                
                                # Останавливаем сервис
                                echo "Останавливаем сервис..."
                                sudo systemctl stop webbooks || true
                                
                                # Делаем бэкап
                                echo "Создаем бэкап..."
                                [ -f "${params.DEPLOY_PATH}/webbooks.jar" ] && sudo cp "${params.DEPLOY_PATH}/webbooks.jar" "${params.DEPLOY_PATH}/webbooks.jar.bak"
                                
                                # Копируем новый артефакт
                                echo "Копируем новый артефакт..."
                                sudo cp /tmp/webbooks.jar "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chown webbooks:webbooks "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chmod 500 "${params.DEPLOY_PATH}/webbooks.jar"
                                
                                # Проверяем права
                                echo "Проверяем права..."
                                ls -la "${params.DEPLOY_PATH}/webbooks.jar"
                                
                                # Перезагружаем systemd
                                echo "Перезагружаем systemd..."
                                sudo systemctl daemon-reload
                                
                                # Запускаем сервис
                                echo "Запускаем сервис..."
                                if ! sudo systemctl start webbooks; then
                                    echo "ERROR: Ошибка при запуске сервиса"
                                    sudo journalctl -u webbooks -n 50 --no-pager
                                    exit 1
                                fi
                                
                                # Проверяем статус
                                echo "Проверяем статус..."
                                sleep 5
                                if [ "\$(sudo systemctl is-active webbooks)" != "active" ]; then
                                    echo "ERROR: Сервис не запустился"
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
                            echo "=== Проверка работоспособности ==="
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                for i in {1..10}; do
                                    echo "Попытка \$i/10..."
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
                            sudo journalctl -u webbooks -n 100 --no-pager || true
                            echo '=== Диск и память ==='
                            df -h
                            free -h
                            echo '=== Проверка JAR-файла ==='
                            if [ -f "${params.DEPLOY_PATH}/webbooks.jar" ]; then
                                ls -la "${params.DEPLOY_PATH}/webbooks.jar"
                                file "${params.DEPLOY_PATH}/webbooks.jar"
                                echo "Попытка проверить JAR:"
                                jar -tf "${params.DEPLOY_PATH}/webbooks.jar" | head -20 || true
                            else
                                echo "JAR-файл не найден в ${params.DEPLOY_PATH}"
                            fi
                        "
                    """
                }
            }
        }
    }
}
