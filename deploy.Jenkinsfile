stage('Deploy') {
    steps {
        script {
            withCredentials([sshUserPrivateKey(
                credentialsId: 'webbooks-ssh-creds',
                keyFileVariable: 'SSH_KEY',
                usernameVariable: 'SSH_USER'
            )]) {
                // 1. Копируем файл на сервер
                sh """
                    scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ACTUAL_ARTIFACT_PATH" $SSH_USER@${params.TARGET_HOST}:/tmp/webbooks.jar
                """
                
                // 2. Выполняем команды развертывания без использования -tt
                def deployScript = """
                    # Проверяем существование файла
                    if [ ! -f "/tmp/webbooks.jar" ]; then
                        echo "Error: Artifact not found on target server"
                        exit 1
                    fi
                    
                    # Останавливаем сервис
                    sudo systemctl stop $SERVICE_NAME || true
                    
                    # Копируем новый артефакт
                    sudo cp /tmp/webbooks.jar ${params.DEPLOY_PATH}/webbooks.jar
                    sudo chown webbooks:webbooks ${params.DEPLOY_PATH}/webbooks.jar
                    
                    # Запускаем сервис
                    sudo systemctl start $SERVICE_NAME
                    sleep 5
                    
                    # Проверяем статус
                    sudo systemctl is-active $SERVICE_NAME
                    exit \$?
                """
                
                // Записываем скрипт во временный файл
                writeFile file: 'deploy.sh', text: deployScript
                
                // Копируем скрипт на сервер и выполняем
                sh """
                    scp -o StrictHostKeyChecking=no -i "$SSH_KEY" deploy.sh $SSH_USER@${params.TARGET_HOST}:/tmp/
                    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" $SSH_USER@${params.TARGET_HOST} '
                        chmod +x /tmp/deploy.sh
                        /tmp/deploy.sh
                        rm -f /tmp/deploy.sh
                    '
                """
            }
        }
    }
}
