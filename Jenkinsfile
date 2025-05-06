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
                        find src/main/java -type f | grep -i "${MAIN_CLASS.replace('.', '/')}.java" || {
                            echo "ERROR: Главный класс не найден!"
                            exit 1
                        }
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
                            # Собираем проект с явным указанием mainClass
                            mvn --batch-mode clean package spring-boot:repackage \\
                            -DDB.url=\${DB_URL} \\
                            -DDB.username=\${DB_USER} \\
                            -DDB.password=\${DB_PASS} \\
                            -Dstart-class=${MAIN_CLASS}
                            
                            # Проверяем MANIFEST.MF
                            echo "=== Проверка MANIFEST.MF ==="
                            unzip -p target/${ARTIFACT_NAME} META-INF/MANIFEST.MF > manifest.txt
                            cat manifest.txt
                            grep "Main-Class: org.springframework.boot.loader.JarLauncher" manifest.txt || {
                                echo "ERROR: Неправильный Main-Class в MANIFEST.MF"
                                exit 1
                            }
                            grep "Start-Class: ${MAIN_CLASS}" manifest.txt || {
                                echo "ERROR: Неправильный Start-Class в MANIFEST.MF"
                                exit 1
                            }
                            
                            # Проверяем наличие главного класса в JAR
                            echo "=== Проверка содержимого JAR ==="
                            jar -tf target/${ARTIFACT_NAME} | grep -i "${MAIN_CLASS.replace('.', '/')}.class" || {
                                echo "ERROR: Главный класс не найден в JAR-файле"
                                exit 1
                            }
                            
                            # Проверяем что артефакт создан
                            if [ ! -f "target/${ARTIFACT_NAME}" ]; then
                                echo "ERROR: Основной артефакт не найден: target/${ARTIFACT_NAME}"
                                ls -la target/
                                exit 1
                            fi
                            
                            # Создаем копию с нужным именем
                            cp "target/${ARTIFACT_NAME}" "target/${FINAL_NAME}"
                            
                            # Дополнительная проверка конечного JAR
                            echo "=== Проверка конечного JAR ==="
                            jar -tf "target/${FINAL_NAME}" > /dev/null || {
                                echo "ERROR: Финальный JAR-файл поврежден"
                                exit 1
                            }
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
                dir('apps/webbooks') {
                    sh """
                        echo "=== Детальная проверка артефакта ==="
                        echo "Размер JAR:"
                        ls -lh target/${FINAL_NAME}
                        echo "Тип файла:"
                        file target/${FINAL_NAME}
                        echo "Проверка запуска:"
                        java -jar target/${FINAL_NAME} --version || echo "Предварительная проверка запуска не удалась"
                    """
                }
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                dir('apps/webbooks') {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    
                    sh """
                        echo "=== Информация о артефактах ==="
                        echo "Содержимое target/:"
                        ls -la target/
                        echo "Размеры файлов:"
                        du -h target/*.jar
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
                    // Проверка перед деплоем
                    def jarCheck = sh(
                        script: "jar -tf apps/webbooks/target/${FINAL_NAME} | grep -i '${MAIN_CLASS.replace('.', '/')}.class'",
                        returnStatus: true
                    )
                    if (jarCheck != 0) {
                        error("Главный класс не найден в JAR-файле! Отмена деплоя.")
                    }
                    
                    def buildNumberStr = "${currentBuild.number}"
                    
                    build job: 'Webbooks-Deploy',
                        parameters: [
                            string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                            string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH),
                            string(name: 'SOURCE_JOB', value: env.JOB_NAME),
                            string(name: 'SOURCE_BUILD_NUMBER', value: buildNumberStr),
                            string(name: 'ARTIFACT_PATH', value: "apps/webbooks/target/${FINAL_NAME}"),
                            string(name: 'MAIN_CLASS', value: env.MAIN_CLASS)
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
                        echo "Содержимое JAR:"
                        jar -tf ${FINAL_NAME} | head -20
                        echo "Проверка главного класса:"
                        jar -tf ${FINAL_NAME} | grep -i "${MAIN_CLASS.replace('.', '/')}.class" || echo "WARNING: Главный класс не найден"
                    """
                }
            }
        }
        
        failure {
            echo "Сборка завершилась с ошибкой. Подробности в логах выше."
            slackSend color: 'danger', message: "Сборка ${env.JOB_NAME} #${env.BUILD_NUMBER} завершилась с ошибкой"
        }
        
        success {
            echo "Сборка успешно завершена!"
            slackSend color: 'good', message: "Сборка ${env.JOB_NAME} #${env.BUILD_NUMBER} успешно завершена"
        }
    }
}
