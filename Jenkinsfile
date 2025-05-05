pipeline {
    agent any
    
    tools {
        maven '3.2.5'
    }
    
    environment {
        DB_URL = 'jdbc:postgresql://10.130.0.24:5432/webbooks'
        DEPLOY_HOST = '10.130.0.24'
        DEPLOY_PATH = '/opt/webbooks'
        ARTIFACT_NAME = 'DigitalLibrary-0.0.1-SNAPSHOT.jar'
    }
    
    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build and Test') {
            steps {
                dir('apps/webbooks') {
                    withCredentials([usernamePassword(
                        credentialsId: 'webbooks-db-creds',
                        usernameVariable: 'DB_USER',
                        passwordVariable: 'DB_PASS'
                    )]) {
                        sh '''
                            mvn --batch-mode clean package \
                            -DDB.url=$DB_URL \
                            -DDB.username=$DB_USER \
                            -DDB.password=$DB_PASS
                        '''
                    }
                }
            }
            
            post {
                always {
                    junit 'apps/webbooks/target/surefire-reports/**/*.xml'
                }
            }
        }
        
        stage('Prepare Artifact') {
            when {
                branch 'main'
            }
            steps {
                dir('apps/webbooks') {
                    // Архивируем с правильным путем
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    
                    // Создаем копию с фиксированным именем
                    sh """
                        cp target/${env.ARTIFACT_NAME} target/webbooks.jar
                    """
                }
            }
        }
        
        stage('Trigger Deploy') {
            when {
                branch 'main'
            }
            steps {
                // Передаем путь к артефакту в параметрах
                build job: 'Webbooks-Deploy',
                    parameters: [
                        string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                        string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH),
                        string(name: 'SOURCE_JOB', value: env.JOB_NAME),
                        string(name: 'ARTIFACT_PATH', value: 'apps/webbooks/target/webbooks.jar')
                    ],
                    wait: false
            }
        }
    }
}
