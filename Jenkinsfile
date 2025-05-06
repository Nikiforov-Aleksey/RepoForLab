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
        MAIN_CLASS = 'web.digitallibrary.DigitalLibraryApplication'
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
                    if ! command -v unzip >/dev/null 2>&1; then
                        sudo apt-get update && sudo apt-get install -y unzip || true
                    fi
                    
                    if ! command -v file >/dev/null 2>&1; then
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
                            echo "Найденные файлы:"
                            find src/main/java -name "*.java"
                            error "Главный класс не найден по пути: src/main/java/${MAIN_CLASS.replace('.', '/')}.java"
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
                            mvn --batch-mode clean package \\
                            -DDB.url=\${DB_URL} \\
                            -DDB.username=\${DB_USER} \\
                            -DDB.password=\${DB_PASS}
                            
                            if [ ! -f "target/${ARTIFACT_NAME}" ]; then
                                echo "ERROR: Основной артефакт не найден"
                                ls -la target/
                                exit 1
                            fi
                            
                            if ! jar -tf "target/${ARTIFACT_NAME}" >/dev/null; then
                                echo "ERROR: JAR-файл поврежден"
                                exit 1
                            fi
                            
                            if ! jar -tf "target/${ARTIFACT_NAME}" | grep -i "${MAIN_CLASS.replace('.', '/')}.class"; then
                                echo "ERROR: Главный класс не найден в JAR"
                                exit 1
                            fi
                            
                            cp "target/${ARTIFACT_NAME}" "target/${FINAL_NAME}"
                            
                            if [ ! -f "target/${FINAL_NAME}" ]; then
                                echo "ERROR: Не удалось создать ${FINAL_NAME}"
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
                    build job: 'Webbooks-Deploy',
                        parameters: [
                            string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                            string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH),
                            string(name: 'SOURCE_JOB', value: env.JOB_NAME),
                            string(name: 'SOURCE_BUILD_NUMBER', value: "${currentBuild.number}"),
                            string(name: 'ARTIFACT_PATH', value: "apps/webbooks/target/${FINAL_NAME}")
                        ],
                        wait: false
                }
            }
        }
    }
    
    post {
        always {
            dir('apps/webbooks/target') {
                sh """
                    echo "=== Финальная проверка ==="
                    ls -la
                    if [ -f "${FINAL_NAME}" ]; then
                        echo "Проверка главного класса:"
                        jar -tf ${FINAL_NAME} | grep -i "${MAIN_CLASS.replace('.', '/')}.class"
                    fi
                """
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
