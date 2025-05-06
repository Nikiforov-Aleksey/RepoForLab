pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target server IP', defaultValue: '10.130.0.24')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory', defaultValue: '/opt/webbooks')
        string(name: 'SOURCE_JOB', description: 'Source job name', defaultValue: 'Webbooks-Multibranch/main')
        string(name: 'SOURCE_BUILD_NUMBER', description: 'Source build number')
        string(name: 'ARTIFACT_PATH', description: 'Artifact path', defaultValue: 'apps/webbooks/target/webbooks.jar')
    }
    
    environment {
        SERVICE_NAME = 'webbooks'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    // Используем SpecificBuildSelector с номером сборки как строкой
                    def buildSelector = [$class: 'SpecificBuildSelector', buildNumber: params.SOURCE_BUILD_NUMBER]
                    
                    // Копируем артефакты
                    step([
                        $class: 'CopyArtifact',
                        projectName: params.SOURCE_JOB,
                        filter: '**/*.jar',
                        selector: buildSelector,
                        target: '.',
                        flatten: true
                    ])
                    
                    // Проверяем что файлы скопированы
                    if (!fileExists(params.ARTIFACT_PATH)) {
                        echo "Ищем любой JAR-файл..."
                        def jars = findFiles(glob: '*.jar')
                        if (jars) {
                            env.ACTUAL_ARTIFACT_PATH = jars[0].path
                            echo "Используем найденный файл: ${env.ACTUAL_ARTIFACT_PATH}"
                        } else {
                            error "Не удалось найти JAR-файлы для деплоя"
                        }
                    } else {
                        env.ACTUAL_ARTIFACT_PATH = params.ARTIFACT_PATH
                    }
                    
                    // Проверяем валидность JAR
                    sh """
                        echo "=== Проверка артефакта ==="
                        echo "Информация о файле:"
                        file "${env.ACTUAL_ARTIFACT_PATH}"
                        echo "Размер файла:"
                        du -h "${env.ACTUAL_ARTIFACT_PATH}"
                        echo "Проверка JAR:"
                        if ! jar -tf "${env.ACTUAL_ARTIFACT_PATH}"; then
                            echo "ERROR: Файл не является валидным JAR-архивом"
                            exit 1
                        fi
                    """
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
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "${env.ACTUAL_ARTIFACT_PATH}" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                            
                            echo "Выполняем деплой..."
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                                set -e
                                echo "Останавливаем сервис..."
                                sudo systemctl stop ${params.SERVICE_NAME} || true
                                
                                echo "Создаем бэкап..."
                                [ -f "${params.DEPLOY_PATH}/webbooks.jar" ] && sudo cp "${params.DEPLOY_PATH}/webbooks.jar" "${params.DEPLOY_PATH}/webbooks.jar.bak"
                                
                                echo "Копируем новый артефакт..."
                                sudo cp /tmp/webbooks.jar "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chown ${params.SERVICE_NAME}:${params.SERVICE_NAME} "${params.DEPLOY_PATH}/webbooks.jar"
                                sudo chmod 500 "${params.DEPLOY_PATH}/webbooks.jar"
                                
                                echo "Проверяем файл на сервере:"
                                ls -la "${params.DEPLOY_PATH}/webbooks.jar"
                                file "${params.DEPLOY_PATH}/webbooks.jar"
                                
                                echo "Перезагружаем systemd..."
                                sudo systemctl daemon-reload
                                
                                echo "Запускаем сервис..."
                                sudo systemctl start ${params.SERVICE_NAME}
                                
                                echo "Проверяем статус..."
                                sleep 5
                                sudo systemctl status ${params.SERVICE_NAME} --no-pager || true
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
                                sudo journalctl -u ${params.SERVICE_NAME} -n 100 --no-pager
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
                            echo '=== Статус сервиса ==='
                            sudo systemctl status ${params.SERVICE_NAME} --no-pager || true
                            echo '=== Последние логи ==='
                            sudo journalctl -u ${params.SERVICE_NAME} -n 100 --no-pager || true
                            echo '=== Проверка JAR ==='
                            if [ -f \"${params.DEPLOY_PATH}/webbooks.jar\" ]; then
                                ls -la \"${params.DEPLOY_PATH}/webbooks.jar\"
                                file \"${params.DEPLOY_PATH}/webbooks.jar\"
                                jar -tf \"${params.DEPLOY_PATH}/webbooks.jar\" | head -20 || true
                            fi
                        "
                    """
                }
            }
        }
    }
}
