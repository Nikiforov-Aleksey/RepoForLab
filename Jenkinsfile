pipeline {
    agent any
    
    tools {
        maven '3.2.5'
    }
    
    environment {
        DB_URL = 'jdbc:postgresql://10.130.0.24:5432/webbooks'
        DEPLOY_HOST = '10.130.0.24'
        DEPLOY_PATH = '/opt/webbooks'
        ARTIFACT_NAME = 'DigitalLibrary-0.0.1-SNAPSHOT.jar' // Оригинальное имя артефакта
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
                            # Собираем проект
                            mvn --batch-mode clean package \
                            -DDB.url=$DB_URL \
                            -DDB.username=$DB_USER \
                            -DDB.password=$DB_PASS
                            
                            # Проверяем что артефакт создан
                            if [ ! -f "target/${env.ARTIFACT_NAME}" ]; then
                                echo "ERROR: Основной артефакт не найден: target/${env.ARTIFACT_NAME}"
                                ls -la target/
                                exit 1
                            fi
                            
                            # Создаем копию с именем webbooks.jar
                            cp "target/${env.ARTIFACT_NAME}" "target/webbooks.jar"
                            
                            # Проверяем что копия создана
                            if [ ! -f "target/webbooks.jar" ]; then
                                echo "ERROR: Не удалось создать webbooks.jar"
                                ls -la target/
                                exit 1
                            fi
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
        
        stage('Archive Artifacts') {
            when {
                branch 'main'
            }
            steps {
                dir('apps/webbooks') {
                    // Архивируем оба артефакта
                    archiveArtifacts artifacts: 'target/webbooks.jar', fingerprint: true
                    archiveArtifacts artifacts: "target/${env.ARTIFACT_NAME}", fingerprint: true
                    
                    // Дополнительная диагностика
                    sh '''
                        echo "Артефакты для архивирования:"
                        ls -la target/webbooks.jar
                        ls -la "target/${env.ARTIFACT_NAME}"
                        echo "Размеры файлов:"
                        du -h target/webbooks.jar
                        du -h "target/${env.ARTIFACT_NAME}"
                    '''
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
                        string(name: 'ARTIFACT_PATH', value: 'apps/webbooks/target/webbooks.jar')
                    ],
                    wait: false
            }
        }
    }
    
    post {
        always {
            script {
                dir('apps/webbooks/target') {
                    sh '''
                        echo "=== Финальная проверка артефактов ==="
                        ls -la
                        echo "Размер webbooks.jar:"
                        du -h webbooks.jar || true
                        echo "Размер оригинального артефакта:"
                        du -h "${env.ARTIFACT_NAME}" || true
                    '''
                }
            }
        }
    }
}
