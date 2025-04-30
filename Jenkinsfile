pipeline {
    agent any

    tools {
        maven 'Maven 3.8.6'  
    }

    environment {
        DB_URL = 'jdbc:postgresql://10.130.0.24:5432/webbooks'
        DB_USERNAME = credentials('db-username')  
        DB_PASSWORD = credentials('db-password')  
    }

    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']], 
                    extensions: [],
                    userRemoteConfigs: [[
                        url: 'https://github.com/Nikiforov-Aleksey/RepoForLab.git',
                        credentialsId: 'your-github-creds'  
                    ]]
                ])
            }
        }

        stage('Build') {
            steps {
                dir('apps/webbooks') {  
                    sh 'mvn clean package -DDB.url=$DB_URL -DDB.username=$DB_USERNAME -DDB.password=$DB_PASSWORD'
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

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                archiveArtifacts 'apps/webbooks/target/*.jar'
                build job: 'Webbooks-Deploy', wait: false
            }
        }
    }
}
