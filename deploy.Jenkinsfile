stage('Deploy') {
    steps {
        script {
            withCredentials([sshUserPrivateKey(
                credentialsId: 'webbooks-ssh-creds',
                keyFileVariable: 'SSH_KEY',
                usernameVariable: 'SSH_USER'
            )]) {
                // Проверяем что файл существует
                if (!fileExists(env.ACTUAL_ARTIFACT_PATH)) {
                    error "Файл ${env.ACTUAL_ARTIFACT_PATH} не найден для деплоя"
                }
                
                sh """
                    echo "=== Копирование артефакта ==="
                    scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "${env.ACTUAL_ARTIFACT_PATH}" ${SSH_USER}@${params.TARGET_HOST}:/tmp/webbooks.jar
                    
                    echo "=== Выполнение деплоя ==="
                    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ${SSH_USER}@${params.TARGET_HOST} '
                        set -e
                        echo "1. Остановка сервиса..."
                        sudo systemctl stop webbooks || true
                        
                        echo "2. Создание бэкапа..."
                        [ -f "/opt/webbooks/webbooks.jar" ] && sudo cp "/opt/webbooks/webbooks.jar" "/opt/webbooks/webbooks.jar.bak.\$(date +%s)"
                        
                        echo "3. Копирование нового артефакта..."
                        sudo cp /tmp/webbooks.jar "/opt/webbooks/webbooks.jar"
                        sudo chown webbooks:webbooks "/opt/webbooks/webbooks.jar"
                        sudo chmod 755 "/opt/webbooks/webbooks.jar"
                        
                        echo "4. Проверка файла..."
                        ls -la "/opt/webbooks/webbooks.jar"
                        sudo jar -tf "/opt/webbooks/webbooks.jar" | grep DigitalLibraryApplication || {
                            echo "ERROR: Главный класс не найден в JAR"
                            exit 1
                        }
                        
                        echo "5. Перезагрузка systemd..."
                        sudo systemctl daemon-reload
                        
                        echo "6. Запуск сервиса..."
                        sudo systemctl start webbooks
                        
                        echo "7. Проверка статуса..."
                        sleep 5
                        sudo systemctl is-active webbooks || {
                            echo "ERROR: Сервис не запустился"
                            sudo journalctl -u webbooks -n 50 --no-pager
                            exit 1
                        }
                    '
                """
            }
        }
    }
}
