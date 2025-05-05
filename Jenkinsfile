pipeline {
    agent any
    
    tools {
        maven '3.2.5'  
    }
    
    environment {
        DB_URL = 'jdbc:postgresql://10.130.0.24:5432/webbooks'
        DB_CREDS = credentials('webbooks-db-creds')
    }
    
    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }
        
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: env.GIT_BRANCH ?: '*/main']],  // Динамическое определение ветки
                    extensions: [
                        [$class: 'CleanBeforeCheckout'],
                        [$class: 'CloneOption', depth: 1, shallow: true]
                    ],
                    userRemoteConfigs: [[url: 'https://github.com/Nikiforov-Aleksey/RepoForLab.git']]
                ])
            }
        }
        
        stage('Build and Test') {
            steps {
                dir('apps/webbooks') {
                    sh """
                        mvn --batch-mode clean package \
                        -DDB.url=${DB_URL} \
                        -DDB.username=${DB_CREDS_USR} \
                        -DDB.password=${DB_CREDS_PSW}
                    """
                }
            }
            
            post {
                always {
                    junit 'apps/webbooks/target/surefire-reports/**/*.xml'
                }
            }
        }
        
        stage('Artifact & Deploy') {
            when {
                branch 'main'  // Только для main ветки
            }
            steps {
                dir('apps/webbooks') {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    
                    // Запуск pipeline для деплоя
                    build job: 'Webbooks-Deploy', 
                        parameters: [
                            string(name: 'ARTIFACT_PATH', value: 'target/webbooks.jar'),
                            string(name: 'TARGET_HOST', value: '10.130.0.24'),
                            string(name: 'DEPLOY_PATH', value: '/opt/webbooks')
                        ],
                        wait: false,
                        propagate: false
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        failure {
            emailext body: "Сборка ${env.JOB_NAME} #${env.BUILD_NUMBER} завершилась неудачно",
                    subject: "FAILED: ${env.JOB_NAME}",
                    to: 'dev-team@example.com'
        }
    }
}
