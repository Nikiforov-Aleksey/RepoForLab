pipeline {
    agent any
    
    parameters {
        string(name: 'ARTIFACT_PATH', description: 'Path to JAR file', defaultValue: 'target/DigitalLibrary-0.0.1-SNAPSHOT.jar')
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
                    // Проверяем, что путь указан
                    if (!params.ARTIFACT_PATH?.trim()) {
                        error("ARTIFACT_PATH parameter is required")
                    }
                    
                    // Ищем артефакт в нескольких возможных местах
                    def artifactPaths = [
                        params.ARTIFACT_PATH,
                        "apps/webbooks/${params.ARTIFACT_PATH}",
                        "var/lib/jenkins/workspace/webbooks/apps/webbooks/${params.ARTIFACT_PATH}",
                        "var/lib/jenkins/jobs/Webbooks-Multibranch/branches/main/builds/lastSuccessfulBuild/archive/${params.ARTIFACT_PATH}"
                    ]
                    
                    def foundArtifact = null
                    for (path in artifactPaths) {
                        if (fileExists(path)) {
                            foundArtifact = path
                            break
                        }
                    }
                    
                    if (!foundArtifact) {
                        error("Artifact file not found at any of: ${artifactPaths.join(', ')}")
                    }
                    
                    // Сохраняем найденный путь для последующих шагов
                    env.ACTUAL_ARTIFACT_PATH = foundArtifact
                }
            }
        }
        
        stage('Copy Artifact') {
            steps {
                sshagent([env.SSH_CREDS]) {
                    sh """
                        echo "Copying artifact from ${env.ACTUAL_ARTIFACT_PATH} to target server"
                        scp -v -o StrictHostKeyChecking=no ${env.ACTUAL_ARTIFACT_PATH} ${env.SSH_CREDS_USR}@${params.TARGET_HOST}:/tmp/webbooks.jar
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
                Искомые пути к артефакту: 
                - ${params.ARTIFACT_PATH}
                - apps/webbooks/${params.ARTIFACT_PATH}
                - /var/lib/jenkins/workspace/webbooks/apps/webbooks/${params.ARTIFACT_PATH}
                - /var/lib/jenkins/jobs/Webbooks-Multibranch/branches/main/builds/lastSuccessfulBuild/archive/${params.ARTIFACT_PATH}
            """,
            subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            to: 'dev-team@example.com'
        }
        success {
            emailext body: """
                Деплой ${env.JOB_NAME} #${env.BUILD_NUMBER} успешно завершен
                Версия: ${env.ACTUAL_ARTIFACT_PATH}
                Сервер: ${params.TARGET_HOST}
                Время: ${currentBuild.durationString}
            """,
            subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            to: 'dev-team@example.com'
        }
    }
}
