pipeline {
    agent any
    
    parameters {
        string(name: 'ARTIFACT_PATH', description: 'Path to built artifact')
        string(name: 'TARGET_HOST', defaultValue: '10.130.0.24', description: 'Target VM host')
        string(name: 'DEPLOY_PATH', defaultValue: '/opt/webbooks', description: 'Deployment path on VM')
    }
    
    environment {
        SSH_CREDS = credentials('vm-ssh-credentials')
    }
    
    stages {
        stage('Copy Artifact') {
            steps {
                script {
                    def artifact = findFiles(glob: "${params.ARTIFACT_PATH}")[0]
                    sshagent([SSH_CREDS]) {
                        sh """
                            scp -o StrictHostKeyChecking=no \
                                ${artifact.path} \
                                ${SSH_CREDS_USR}@${params.TARGET_HOST}:${params.DEPLOY_PATH}/webbooks.jar
                        """
                    }
                }
            }
        }
        
        stage('Restart Service') {
            steps {
                sshagent([SSH_CREDS]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no \
                            ${SSH_CREDS_USR}@${params.TARGET_HOST} \
                            "sudo systemctl restart webbooks.service"
                    """
                }
            }
        }
    }
    
    post {
        success {
            slackSend channel: '#deployments',
                     message: "Успешный деплой webbooks на ${params.TARGET_HOST}"
        }
        failure {
            emailext body: "Деплой ${env.JOB_NAME} #${env.BUILD_NUMBER} завершился неудачно",
                    subject: "DEPLOY FAILED: ${env.JOB_NAME}",
                    to: 'scyvocer@gmail.com'
        }
    }
}
