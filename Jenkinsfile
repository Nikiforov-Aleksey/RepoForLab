pipeline {
    agent any

    stages {
        stage('Checkout & Build') {
            steps {
                checkout scm
                sh './mvnw clean package'
            }
        }

        stage('Unit Tests') {
            when {
                changeRequest() 
            }
            steps {
                sh './mvnw test'
            }
            post {
                always {
                    junit 'target/surefire-reports/**/*.xml' 
                }
            }
        }

        stage('Build Artifact & Deploy') {
            when {
                branch 'main'  
            }
            steps {
                archiveArtifacts 'target/*.jar'
                build job: 'Webbooks-Deploy', wait: false 
            }
        }
    }
}
