pipeline {
    agent any
    
    parameters {
        string(name: 'ARTIFACT_PATH', description: 'Path to JAR file', defaultValue: 'apps/webbooks/target/DigitalLibrary-0.0.1-SNAPSHOT.jar')
        string(name: 'TARGET_HOST', description: 'Target server IP', defaultValue: '10.130.0.24')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory', defaultValue: '/opt/webbooks')
    }
    
    environment {
        SSH_CREDS = credentials('webbooks-ssh-creds')
        SERVICE_NAME = 'webbooks'
    }
    
    stages {
        stage('Validate Parameters') {
            steps {
                script {
                    if (!params.ARTIFACT_PATH?.trim()) {
                        error("ARTIFACT_PATH parameter is required")
                    }
                    if (!fileExists(params.ARTIFACT_PATH)) {
                        error("Artifact file not found at ${params.ARTIFACT_PATH}")
                    }
                }
            }
        }
        
        stage('Copy Artifact') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        scp -v -o StrictHostKeyChecking=no ${params.ARTIFACT_PATH} ${env.SSH_CREDS_USR}@${params.TARGET_HOST}:/tmp/webbooks.jar
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        ssh -v -o StrictHostKeyChecking=no ${env.SSH_CREDS_USR}@${params.TARGET_HOST} "
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
            """,
            subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            to: 'dev-team@example.com'
        }
        success {
            emailext body: """
                Деплой ${env.JOB_NAME} #${env.BUILD_NUMBER} успешно завершен
                Версия: ${params.ARTIFACT_PATH}
                Сервер: ${params.TARGET_HOST}
                Время: ${currentBuild.durationString}
            """,
            subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            to: 'dev-team@example.com'
        }
    }
}
