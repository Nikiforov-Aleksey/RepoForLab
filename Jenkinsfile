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
                        // Используем двойные кавычки для Groovy и одинарные для shell
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
                        echo "Артефакты для архивирования:"
                        ls -la target/${FINAL_NAME}
                        ls -la target/${ARTIFACT_NAME}
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
                    // Используем явное обращение к переменным через env
                    sh '''
                        echo "=== Финальная проверка артефактов ==="
                        ls -la
                        echo "Размер webbooks.jar:"
                        if [ -f "webbooks.jar" ]; then
                            du -h webbooks.jar
                        else
                            echo "Файл webbooks.jar не найден"
                        fi
                        echo "Размер оригинального артефакта:"
                        if [ -f "$ARTIFACT_NAME" ]; then
                            du -h "$ARTIFACT_NAME"
                        else
                            echo "Файл $ARTIFACT_NAME не найден"
                        fi
                    '''
                }
            }
        }
    }
}
