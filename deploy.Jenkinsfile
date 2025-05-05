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
                        """
                    }
                    
                    if (!fileExists('webbooks.jar')) {
                        error("Не удалось скачать артефакт из ${artifactUrl}")
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
                        // 1. Копируем артефакт
                        sh """
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                        """
                        
                        // 2. Создаем скрипт деплоя
                        def deployScript = '''
                            #!/bin/bash
                            set -ex

                            # Проверяем артефакт
                            if [ ! -f "/tmp/webbooks.jar" ]; then
                                echo "ERROR: Артефакт не найден в /tmp/webbooks.jar"
                                exit 1
                            fi

                            # Останавливаем сервис
                            sudo systemctl stop webbooks || true

                            # Бэкапим предыдущую версию
                            sudo cp /opt/webbooks/webbooks.jar /opt/webbooks/webbooks.jar.bak || true

                            # Развертываем новую версию
                            sudo cp /tmp/webbooks.jar /opt/webbooks/webbooks.jar
                            sudo chown webbooks:webbooks /opt/webbooks/webbooks.jar

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
                        
                        // 3. Выполняем деплой
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
                                # Ожидаем готовности сервиса
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
                // Получаем логи сервиса при ошибке
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'webbooks-ssh-creds',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                            echo "=== Статус сервиса Webbooks ==="
                            sudo systemctl status webbooks --no-pager || true
                            echo "=== Последние логи ==="
                            sudo journalctl -u webbooks -n 50 --no-pager || true
                        '
                    """
                }
            }
        }
    }
}
