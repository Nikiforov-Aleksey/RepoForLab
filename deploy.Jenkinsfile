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
                    // Получаем номер последней успешной сборки
                    def buildInfo = build(job: params.SOURCE_JOB, propagate: false, wait: true)
                    def buildNumber = buildInfo.number
                    
                    // Формируем URL артефакта (исправлено экранирование)
                    def artifactUrl = "${env.JENKINS_URL}job/${params.SOURCE_JOB.replace('/', '/job/')}/${buildNumber}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Скачиваем артефакт из: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        // Исправленная команда curl (убраны лишние кавычки)
                        sh """
                            curl -sSL -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
                            
                            # Проверка JAR-файла
                            if ! jar -tf webbooks.jar >/dev/null 2>&1; then
                                echo "ERROR: Скачанный файл не является валидным JAR-архивом"
                                exit 1
                            fi
                            
                            filesize=\$(stat -c%s webbooks.jar)
                            if [ "\$filesize" -lt 10000 ]; then
                                echo "ERROR: JAR-файл слишком мал (\${filesize} bytes)"
                                exit 1
                            fi
                        """
                    }
                    
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        // Остальные стадии остаются без изменений
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
                        
                        // Используем ваш deployScript без изменений
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
        
        stage('Verify') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'webbooks-ssh-creds',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )]) {
                        sh '''
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
                        '''
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
                        sh '''
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} "rm -f /tmp/webbooks.jar" || true
                        '''
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
                    sh '''
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} "
                            echo '=== Статус сервиса Webbooks ==='
                            sudo systemctl status webbooks --no-pager || true
                            echo '=== Последние логи ==='
                            sudo journalctl -u webbooks -n 50 --no-pager || true
                        "
                    '''
                }
            }
        }
    }
}
