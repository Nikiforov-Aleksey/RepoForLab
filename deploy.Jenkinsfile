pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target server IP', defaultValue: '10.130.0.24')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory', defaultValue: '/opt/webbooks')
    }
    
    environment {
        SSH_CREDS = credentials('webbooks-ssh-creds')
        SERVICE_NAME = 'webbooks'
        ARTIFACT_NAME = 'DigitalLibrary-0.0.1-SNAPSHOT.jar'  // Указываем реальное имя файла
    }
    
    stages {
        stage('Copy Artifact from Build Job') {
            steps {
                // Копируем артефакт из предыдущего успешного билда
                copyArtifacts(
                    projectName: 'Webbooks-Multibranch/main',  // Имя исходного джоба
                    selector: lastSuccessful(),                // Берем последний успешный билд
                    filter: "apps/webbooks/target/${env.ARTIFACT_NAME}",  // Правильный путь к артефакту
                    target: '.',                              // Копируем в текущую директорию
                    flatten: true                             // Игнорируем структуру папок
                )
                
                // Переименовываем файл для удобства (если нужно)
                sh "mv ${env.ARTIFACT_NAME} webbooks.jar"
                
                script {
                    if (!fileExists('webbooks.jar')) {
                        error("Failed to copy artifact from build job")
                    }
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        stage('Copy Artifact to Target Server') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        echo "Copying artifact to target server"
                        scp -o StrictHostKeyChecking=no ${env.ACTUAL_ARTIFACT_PATH} ${env.SSH_CREDS_USR}@${params.TARGET_HOST}:/tmp/webbooks.jar
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "
                            echo 'Stopping service...'
                            sudo systemctl stop ${env.SERVICE_NAME} || true
                            
                            echo 'Deploying new version...'
                            sudo cp /tmp/webbooks.jar ${params.DEPLOY_PATH}/webbooks.jar
                            sudo chown webbooks:webbooks ${params.DEPLOY_PATH}/webbooks.jar
                            
                            echo 'Starting service...'
                            sudo systemctl start ${env.SERVICE_NAME}
                            sleep 5
                        "
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    script {
                        def status = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "
                                    sudo systemctl is-active ${env.SERVICE_NAME} && \
                                    curl -s --connect-timeout 10 http://localhost:8080/actuator/health | grep -q '\"status\":\"UP\"'
                                "
                            """,
                            returnStatus: true
                        )
                        
                        if (status != 0) {
                            error("Service verification failed")
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
            sshagent([env.SSH_CREDS]) {
                sh """
                    ssh -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "rm -f /tmp/webbooks.jar" || true
                """
            }
        }
        failure {
            emailext body: """
                Сборка ${env.JOB_NAME} #${env.BUILD_NUMBER} завершилась неудачно
                URL сборки: ${env.BUILD_URL}
                Причина: ${currentBuild.currentResult}
                Путь к артефакту: ${env.ACTUAL_ARTIFACT_PATH}
            """,
            subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            to: 'dev-team@example.com'
        }
        success {
            emailext body: """
                Деплой ${env.JOB_NAME} #${env.BUILD_NUMBER} успешно завершен
                Сервер: ${params.TARGET_HOST}
                Время: ${currentBuild.durationString}
            """,
            subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            to: 'dev-team@example.com'
        }
    }
}
