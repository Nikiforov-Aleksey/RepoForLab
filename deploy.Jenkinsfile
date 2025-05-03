pipeline {
    agent any
    parameters {
        string(name: 'ARTIFACT_PATH', description: 'Path to JAR file')
    }
    environment {
        DEPLOY_VM = '10.130.0.24'
        DEPLOY_USER = 'deploy-user'
        DEPLOY_DIR = '/opt/webbooks'
        SSH_CREDS = 'vm-ssh-key'  # ID SSH-ключа в Jenkins
    }
    stages {
        stage('Deploy') {
            steps {
                sshagent([SSH_CREDS]) {
                    sh """
                    scp -o StrictHostKeyChecking=no ${params.ARTIFACT_PATH} ${DEPLOY_USER}@${DEPLOY_VM}:${DEPLOY_DIR}/
                    ssh ${DEPLOY_USER}@${DEPLOY_VM} 'systemctl restart webbooks'
                    """
                }
            }
        }
    }
    post {
        success {
            slackSend channel: '#devops', message: "Деплой успешен: ${env.BUILD_URL}"
        }
        failure {
            slackSend channel: '#devops', color: 'danger', message: "Ошибка деплоя: ${env.BUILD_URL}"
        }
    }
}
