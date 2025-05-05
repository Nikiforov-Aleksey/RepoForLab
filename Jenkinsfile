pipeline {
    agent any
    
    tools {
        maven 'Maven 3.8.6'  // Используем установленный Maven
    }
    
    environment {
        DB_URL = 'jdbc:postgresql://10.130.0.24:5432/webbooks'
        DB_CREDS = credentials('webbooks-db-creds') 
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: env.GIT_BRANCH ?: '*/main']],
                    extensions: [[$class: 'CleanBeforeCheckout']],  // Очистка перед checkout
                    userRemoteConfigs: [[url: env.GIT_URL]]
                ])
            }
        }
        
        stage('Build') {
            steps {
                dir('apps/webbooks') {
                    // Явно используем mvn из tools
                    sh """
                        mvn clean package \
                        -DDB.url=${DB_URL} \
                        -DDB.username=${DB_CREDS_USR} \
                        -DDB.password=${DB_CREDS_PSW}
                    """
                }
            }
        }
        
        stage('Unit Tests') {
            when {
                changeRequest()
            }
            steps {
                dir('apps/webbooks') {
                    sh 'mvn test'  // Используем mvn, а не ./mvnw
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
                branch 'main'
            }
            steps {
                dir('apps/webbooks') {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    build job: 'Webbooks-Deploy', 
                        parameters: [
                            string(name: 'ARTIFACT_PATH', value: 'apps/webbooks/target/webbooks.jar')
                        ], 
                        wait: false,
                        propagate: false
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()  // Очистка workspace после сборки
        }
    }
}
