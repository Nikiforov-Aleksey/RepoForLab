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
        
        stage('Install unzip') {
            steps {
                sh '''
                    # Устанавливаем unzip если отсутствует
                    if ! command -v unzip >/dev/null 2>&1; then
                        echo "Устанавливаем unzip..."
                        sudo apt-get update && sudo apt-get install -y unzip || true
                    fi
                '''
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
                            
                            # Проверяем валидность JAR (используем jar вместо unzip)
                            if ! jar -tf "target/${ARTIFACT_NAME}" >/dev/null 2>&1; then
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
                    archiveArtifacts artifacts: "target/${FINAL_NAME}", fingerprint: true
                    archiveArtifacts artifacts: "target/${ARTIFACT_NAME}", fingerprint: true
                    
                    sh """
                        echo "=== Информация о артефактах ==="
                        echo "Размер ${FINAL_NAME}:"
                        du -h "target/${FINAL_NAME}"
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
                build job: 'Webbooks-Deploy',
                    parameters: [
                        string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                        string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH),
                        string(name: 'SOURCE_JOB', value: env.JOB_NAME),
                        string(name: 'ARTIFACT_PATH', value: "apps/webbooks/target/${FINAL_NAME}")
                    ],
                    wait: false
            }
        }
    }
    
    post {
        always {
            script {
                dir('apps/webbooks/target') {
                    sh """
                        echo "=== Финальная проверка артефактов ==="
                        ls -la
                        echo "Проверка JAR:"
                        jar -tf ${FINAL_NAME} || echo "Проверка не удалась"
                    """
                }
            }
        }
        
        failure {
            echo "Сборка завершилась с ошибкой. Подробности в логах выше."
            // Убрали slackSend, так как плагин не установлен
        }
        
        success {
            echo "Сборка успешно завершена!"
        }
    }
}
