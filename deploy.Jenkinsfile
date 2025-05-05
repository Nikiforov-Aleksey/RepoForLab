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
                    // Ожидаем завершения сборки и получаем информацию
                    def buildInfo = build(
                        job: params.SOURCE_JOB,
                        propagate: false,
                        wait: true,
                        parameters: []
                    )
                    
                    if (buildInfo.result != 'SUCCESS') {
                        error "Сборка ${params.SOURCE_JOB} завершилась со статусом ${buildInfo.result}"
                    }
                    
                    // Формируем корректный URL для многоуровневых job
                    def jobPath = params.SOURCE_JOB.replace('/', '/job/')
                    def artifactUrl = "${env.JENKINS_URL}job/${jobPath}/${buildInfo.number}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Скачиваем артефакт из: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            # Скачиваем артефакт с подробным логом
                            curl -v -sSL -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
                            
                            # Проверяем, что файл скачан
                            if [ ! -f "webbooks.jar" ]; then
                                echo "ERROR: Файл артефакта не был скачан"
                                exit 1
                            fi
                            
                            # Проверяем размер файла
                            filesize=\$(stat -c%s webbooks.jar)
                            echo "Размер файла: \${filesize} байт"
                            
                            if [ "\$filesize" -lt 10000 ]; then
                                echo "ERROR: Размер файла слишком мал (\${filesize} bytes), возможно ошибка загрузки"
                                echo "Первые 100 байт файла:"
                                xxd -l 100 webbooks.jar
                                exit 1
                            fi
                            
                            # Проверяем, что это валидный JAR-файл
                            if ! jar -tf webbooks.jar >/dev/null 2>&1; then
                                echo "ERROR: Скачанный файл не является валидным JAR-архивом"
                                echo "Тип файла:"
                                file webbooks.jar
                                echo "Начало файла (hexdump):"
                                xxd -l 100 webbooks.jar
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
                        // Копируем файл на сервер
                        sh """
                            echo "Копируем артефакт на сервер..."
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                        """
                        
                        // Создаем скрипт деплоя
                        def deployScript = '''#!/bin/bash
                            set -exo pipefail

                            # Проверки
                            if [ ! -f "/tmp/webbooks.jar" ]; then
                                echo "ERROR: Артефакт не найден в /tmp/webbooks.jar"
                                exit 1
                            fi

                            if ! jar -tf /tmp/webbooks.jar >/dev/null 2>&1; then
                                echo "ERROR: Файл не является валидным JAR-архивом"
                                exit 1
                            fi

                            # Останавливаем сервис
                            sudo systemctl stop webbooks || true

                            # Бэкап
                            [ -f "${params.DEPLOY_PATH}/webbooks.jar" ] && sudo cp "${params.DEPLOY_PATH}/webbooks.jar" "${params.DEPLOY_PATH}/webbooks.jar.bak"

                            # Развертывание
                            sudo cp /tmp/webbooks.jar "${params.DEPLOY_PATH}/webbooks.jar"
                            sudo chown webbooks:webbooks "${params.DEPLOY_PATH}/webbooks.jar"
                            sudo chmod 500 "${params.DEPLOY_PATH}/webbooks.jar"

                            # Обновляем systemd
                            sudo systemctl daemon-reload

                            # Запускаем сервис
                            echo "Запуск сервиса webbooks..."
                            sudo systemctl start webbooks

                            # Проверяем
                            sleep 5
                            service_status=$(sudo systemctl is-active webbooks)
                            if [ "$service_status" != "active" ]; then
                                echo "ERROR: Не удалось запустить сервис. Текущий статус: $service_status"
                                sudo journalctl -u webbooks -n 50 --no-pager
                                exit 1
                            fi
                            echo "Сервис успешно запущен"
                        '''
                        
                        writeFile file: 'deploy.sh', text: deployScript
                        
                        // Выполняем деплой
                        sh """
                            echo "Выполняем деплой на сервере..."
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
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} "
                                # Ожидаем готовности сервиса
                                for i in {1..10}; do
                                    if curl -s --connect-timeout 5 http://localhost:8080/actuator/health | grep -q '"status":"UP"'; then
                                        echo "Health check пройден"
                                        exit 0
                                    fi
                                    sleep 5
                                done
                                echo "ERROR: Health check не пройден после 50 секунд ожидания"
                                sudo journalctl -u webbooks -n 50 --no-pager
                                exit 1
                            "
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
                            echo "Очищаем временные файлы на сервере..."
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
                        echo "Собираем информацию об ошибке..."
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
        success {
            echo "Деплой успешно завершен!"
        }
    }
}
