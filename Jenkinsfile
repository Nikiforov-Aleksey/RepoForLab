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
        FINAL_NAME = 'webbooks.jar'
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
                        sh """
                            # Собираем проект
                            mvn --batch-mode clean package \\
                            -DDB.url=\$DB_URL \\
                            -DDB.username=\$DB_USER \\
                            -DDB.password=\$DB_PASS
                            
                            # Проверяем что артефакт создан
                            if [ ! -f "target/${ARTIFACT_NAME}" ]; then
                                echo "ERROR: Основной артефакт не найден: target/${ARTIFACT_NAME}"
                                ls -la target/
                                exit 1
                            fi
                            
                            # Проверяем валидность JAR
                            if ! unzip -t "target/${ARTIFACT_NAME}" >/dev/null; then
                                echo "ERROR: JAR-файл поврежден или невалиден"
                                exit 1
                            fi
                            
                            # Создаем копию с нужным именем
                            cp "target/${ARTIFACT_NAME}" "target/${FINAL_NAME}"
                            
                            # Проверяем что копия создана
                            if [ ! -f "target/${FINAL_NAME}" ]; then
                                echo "ERROR: Не удалось создать ${FINAL_NAME}"
                                ls -la target/
                                exit 1
                            fi
                        """
                    }
                }
            }
            
            post {
                always {
                    junit 'apps/webbooks/target/surefire-reports/**/*.xml'
                }
            }
        }
        
        stage('Archive Artifacts') {
            when {
                branch 'main'
            }
            steps {
                dir('apps/webbooks') {
                    // Архивируем оба артефакта
                    archiveArtifacts artifacts: "target/${FINAL_NAME}", fingerprint: true
                    archiveArtifacts artifacts: "target/${ARTIFACT_NAME}", fingerprint: true
                    
                    // Диагностика
                    sh """
                        echo "=== Информация о артефактах ==="
                        echo "Размер ${FINAL_NAME}:"
                        du -h "target/${FINAL_NAME}"
                        echo "Тип файла:"
                        file "target/${FINAL_NAME}"
                        echo "MD5:"
                        md5sum "target/${FINAL_NAME}" || true
                    """
                }
            }
        }
        
        stage('Trigger Deploy') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Явно преобразуем номер сборки в строку
                    def buildNumberStr = "${currentBuild.number}"
                    
                    build job: 'Webbooks-Deploy',
                        parameters: [
                            string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                            string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH),
                            string(name: 'SOURCE_JOB', value: env.JOB_NAME),
                            string(name: 'SOURCE_BUILD_NUMBER', value: buildNumberStr), // Передаем как строку
                            string(name: 'ARTIFACT_PATH', value: "apps/webbooks/target/${FINAL_NAME}")
                        ],
                        wait: false
                }
            }
        }
    }
    
    post {
        always {
            script {
                dir('apps/webbooks/target') {
                    sh """
                        echo "=== Финальная проверка артефактов ==="
                        echo "Содержимое target/:"
                        ls -la
                        echo "Информация о JAR:"
                        file ${FINAL_NAME}
                        echo "Проверка целостности:"
                        unzip -t ${FINAL_NAME} || echo "Проверка не удалась"
                    """
                }
            }
        }
        
        failure {
            slackSend color: 'danger', 
                     message: "Сборка ${env.JOB_NAME} #${env.BUILD_NUMBER} завершилась с ошибкой: ${currentBuild.currentResult}"
        }
        
        success {
            slackSend color: 'good', 
                     message: "Сборка ${env.JOB_NAME} #${env.BUILD_NUMBER} успешно завершена"
        }
    }
}
