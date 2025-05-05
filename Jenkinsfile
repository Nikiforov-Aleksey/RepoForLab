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
                        sh '''
                            mvn --batch-mode clean package \
                            -DDB.url=$DB_URL \
                            -DDB.username=$DB_USER \
                            -DDB.password=$DB_PASS
                        '''
                    }
                }
            }
            
            post {
                always {
                    junit 'apps/webbooks/target/surefire-reports/**/*.xml'
                }
            }
        }
        
        stage('Prepare Artifact') {
            when {
                branch 'main'
            }
            steps {
                dir('apps/webbooks') {
                    // Архивируем оригинальный артефакт
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    
                    // Переименовываем артефакт для деплоя
                    sh """
                        # Проверяем что оригинальный артефакт существует
                        if [ ! -f "target/${env.ARTIFACT_NAME}" ]; then
                            echo "ERROR: Основной артефакт не найден: target/${env.ARTIFACT_NAME}"
                            exit 1
                        fi
                        
                        # Копируем с новым именем
                        cp "target/${env.ARTIFACT_NAME}" "target/webbooks.jar"
                        
                        # Проверяем что копия создана
                        if [ ! -f "target/webbooks.jar" ]; then
                            echo "ERROR: Не удалось создать webbooks.jar"
                            exit 1
                        fi
                    """
                    
                    // Архивируем копию с фиксированным именем
                    archiveArtifacts artifacts: 'target/webbooks.jar', fingerprint: true
                }
            }
        }
        
        stage('Trigger Deploy') {
            when {
                branch 'main'
            }
            steps {
                // Передаем путь к артефакту в параметрах
                build job: 'Webbooks-Deploy',
                    parameters: [
                        string(name: 'TARGET_HOST', value: env.DEPLOY_HOST),
                        string(name: 'DEPLOY_PATH', value: env.DEPLOY_PATH),
                        string(name: 'SOURCE_JOB', value: env.JOB_NAME),
                        string(name: 'ARTIFACT_PATH', value: 'apps/webbooks/target/webbooks.jar')
                    ],
                    wait: false
            }
        }
    }
    
    post {
        always {
            // Дополнительная диагностика
            script {
                try {
                    dir('apps/webbooks/target') {
                        sh '''
                            echo "Содержимое target директории:"
                            ls -la
                            echo "Размер webbooks.jar:"
                            du -h webbooks.jar
                        '''
                    }
                } catch (e) {
                    echo "Не удалось выполнить диагностику: ${e}"
                }
            }
        }
    }
}
