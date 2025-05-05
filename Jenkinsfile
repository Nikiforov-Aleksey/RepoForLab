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
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build') {
            steps {
                dir('apps/webbooks') {
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
                    sh 'mvn test'  
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
                archiveArtifacts 'apps/webbooks/target/*.jar'
                build job: 'Webbooks-Deploy', parameters: [
                    string(name: 'ARTIFACT_PATH', value: 'apps/webbooks/target/webbooks.jar')
                ], wait: false
            }
        }
    }
}
