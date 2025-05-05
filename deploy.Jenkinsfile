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
                    
                    echo "Скачиваем артефакт из: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            curl -sSL -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
                            
                            # Проверка JAR-файла
                            if ! jar -tf webbooks.jar >/dev/null 2>&1; then
                                echo "ERROR: Скачанный файл не является валидным JAR-архивом"
                                exit 1
                            fi
                            
                            filesize=$(stat -c%s webbooks.jar)
                            if [ "$filesize" -lt 10000 ]; then
                                echo "ERROR: JAR-файл слишком мал (${filesize} bytes)"
                                exit 1
                            fi
                        """
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
                        // Копируем файл на сервер
                        sh """
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                        """
                        
                        // Создаем скрипт деплоя
                        def deployScript = '''
                            #!/bin/bash
                            set -ex

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
                            [ -f "/opt/webbooks/webbooks.jar" ] && sudo cp /opt/webbooks/webbooks.jar /opt/webbooks/webbooks.jar.bak

                            # Развертывание
                            sudo cp /tmp/webbooks.jar /opt/webbooks/webbooks.jar
                            sudo chown webbooks:webbooks /opt/webbooks/webbooks.jar
                            sudo chmod 500 /opt/webbooks/webbooks.jar

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
        
        // ... остальные этапы без изменений ...
    }
    
    // ... post-секция без изменений ...
}
