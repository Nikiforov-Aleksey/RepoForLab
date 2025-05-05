pipeline {
    agent any
    
    tools {
        maven '3.2.5'
    }
    
    environment {
        DB_URL = 'jdbc:postgresql://10.130.0.24:5432/webbooks'
        DEPLOY_HOST = '10.130.0.24'
        DEPLOY_PATH = '/opt/webbooks'
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
        
        stage('Archive and Prepare Artifact') {
            when {
                branch 'main'
            }
            steps {
                dir('apps/webbooks') {
                    // Архивируем артефакт для копирования между джобами
                    archiveArtifacts artifacts: 'target/webbooks.jar', fingerprint: true
                    
                    // Также сохраняем в stash для передачи внутри пайплайна (если нужно)
                    stash name: 'webbooks-artifact', includes: 'target/webbooks.jar'
                }
            }
        }
        
        stage('Trigger Deploy') {
            when {
                branch 'main'
            }
            steps {
                build job: 'Webbooks-Deploy',
                    parameters: [
                        string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                        string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH)
                    ],
                    wait: false
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
