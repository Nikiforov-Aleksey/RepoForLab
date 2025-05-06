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
        MAIN_CLASS = 'com.example.DigitalLibraryApplication'
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
        
        stage('Install Tools') {
            steps {
                sh '''
                    # Устанавливаем необходимые утилиты
                    if ! command -v unzip >/dev/null 2>&1; then
                        echo "Устанавливаем unzip..."
                        sudo apt-get update && sudo apt-get install -y unzip || true
                    fi
                    
                    if ! command -v file >/dev/null 2>&1; then
                        echo "Устанавливаем file..."
                        sudo apt-get install -y file || true
                    fi
                '''
            }
        }
        
        stage('Verify Project Structure') {
            steps {
                dir('apps/webbooks') {
                    sh """
                        echo "=== Проверка структуры проекта ==="
                        echo "Ищем главный класс: ${MAIN_CLASS}"
                        if [ ! -f "src/main/java/${MAIN_CLASS.replace('.', '/')}.java" ]; then
                            echo "ERROR: Главный класс не найден!"
                            ls -R src/main/java/
                            exit 1
                        fi
                    """
                }
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
                            -DDB.url=\${DB_URL} \\
                            -DDB.username=\${DB_USER} \\
                            -DDB.password=\${DB_PASS}
                            
                            # Проверяем что основной артефакт создан
                            if [ ! -f "target/${ARTIFACT_NAME}" ]; then
                                echo "ERROR: Основной артефакт не найден: target/${ARTIFACT_NAME}"
                                ls -la target/
                                exit 1
                            fi
                            
                            # Проверяем валидность JAR
                            if ! jar -tf "target/${ARTIFACT_NAME}" >/dev/null 2>&1; then
                                echo "ERROR: JAR-файл поврежден или невалиден"
                                exit 1
                            fi
                            
                            # Проверяем наличие главного класса
                            if ! jar -tf "target/${ARTIFACT_NAME}" | grep -i "${MAIN_CLASS.replace('.', '/')}.class"; then
                                echo "ERROR: Главный класс не найден в JAR-файле"
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
        
        stage('Verify Artifact') {
            steps {
                dir('apps/webbooks/target') {
                    sh """
                        echo "=== Детальная проверка артефакта ==="
                        echo "Содержимое директории:"
                        ls -la
                        echo "Проверка JAR-файла:"
                        jar -tf ${FINAL_NAME} | head -20
                        echo "Проверка главного класса:"
                        jar -tf ${FINAL_NAME} | grep -i "${MAIN_CLASS.replace('.', '/')}.class" || {
                            echo "ERROR: Главный класс не найден в финальном JAR"
                            exit 1
                        }
                    """
                }
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                dir('apps/webbooks') {
                    archiveArtifacts artifacts: "target/${FINAL_NAME}", fingerprint: true
                }
            }
        }
        
        stage('Trigger Deploy') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def buildNumberStr = "${currentBuild.number}"
                    
                    build job: 'Webbooks-Deploy',
                        parameters: [
                            string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                            string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH),
                            string(name: 'SOURCE_JOB', value: env.JOB_NAME),
                            string(name: 'SOURCE_BUILD_NUMBER', value: buildNumberStr),
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
                        echo "=== Финальная проверка ==="
                        echo "Содержимое директории:"
                        ls -la
                        echo "Проверка JAR:"
                        if [ -f "${FINAL_NAME}" ]; then
                            jar -tf ${FINAL_NAME} | head -20
                            jar -tf ${FINAL_NAME} | grep -i "${MAIN_CLASS.replace('.', '/')}.class" || echo "WARNING: Главный класс не найден"
                        else
                            echo "ERROR: Файл ${FINAL_NAME} не существует!"
                            exit 1
                        fi
                    """
                }
            }
        }
        
        failure {
            echo "Сборка завершилась с ошибкой. Подробности в логах выше."
        }
        
        success {
            echo "Сборка успешно завершена!"
        }
    }
}
