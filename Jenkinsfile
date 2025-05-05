pipeline {
    agent any
    
    tools {
        maven 'Maven 3.2.5'  
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
                    branches: [[name: '*/test']],
                    extensions: [
                        [$class: 'CleanBeforeCheckout'],  
                        [$class: 'CloneOption', depth: 1, shallow: true]  
                    ],
                    userRemoteConfigs: [[url: 'https://github.com/Nikiforov-Aleksey/RepoForLab.git']]
                ])
            }
        }
        
        stage('Verify Environment') {
            steps {
                script {
                    echo "Maven version:"
                    sh "mvn --version"  
                    
                    echo "Workspace content:"
                    sh "ls -la apps/webbooks" 
                }
            }
        }
        
        stage('Build') {
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
        }
        
        stage('Unit Tests') {
            when {
                changeRequest()
            }
            steps {
                dir('apps/webbooks') {
                    sh 'mvn --batch-mode test'
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
            cleanWs() 
        }
    }
}
