pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', defaultValue: '10.130.0.24', description: 'Target server IP')
        string(name: 'DEPLOY_PATH', defaultValue: '/opt/webbooks', description: 'Deployment directory')
        string(name: 'SOURCE_JOB', defaultValue: 'Webbooks-Multibranch/main', description: 'Source job name')
        string(name: 'ARTIFACT_PATH', defaultValue: '**/webbooks.jar', description: 'Artifact path pattern')
    }
    
    environment {
        SERVICE_NAME = 'webbooks'
        JENKINS_URL = 'http://158.160.184.242:8080/'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    // Получаем информацию о последней успешной сборке
                    def buildInfo = build(
                        job: params.SOURCE_JOB,
                        propagate: false,
                        wait: true,
                        parameters: []
                    )
                    
                    if (buildInfo.result != 'SUCCESS') {
                        error "Сборка ${params.SOURCE_JOB} завершилась со статусом ${buildInfo.result}"
                    }
                    
                    // Получаем список артефактов через API Jenkins
                    def artifacts = Jenkins.instance.getItemByFullName(params.SOURCE_JOB)
                        .getBuildByNumber(buildInfo.number)
                        .getArtifacts()
                    
                    if (artifacts.isEmpty()) {
                        error "Нет артефактов в сборке ${buildInfo.number}"
                    }
                    
                    // Ищем нужный артефакт по паттерну
                    def jarArtifact = artifacts.find { it.relativePath =~ /webbooks\.jar$/ }
                    if (!jarArtifact) {
                        error "Не найден webbooks.jar среди артефактов: ${artifacts.collect { it.relativePath }}"
                    }
                    
                    // Формируем корректный URL для скачивания
                    def artifactUrl = "${env.JENKINS_URL}job/${params.SOURCE_JOB.replace('/', '/job/')}/${buildInfo.number}/artifact/${jarArtifact.relativePath}"
                    
                    echo "Скачиваем артефакт из: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            # Скачиваем с подробным логом
                            curl -v -f -L -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
                            
                            # Проверяем что файл скачан
                            if [ ! -f "webbooks.jar" ]; then
                                echo "ERROR: Файл артефакта не был скачан"
                                exit 1
                            fi
                            
                            # Проверяем что это действительно JAR
                            if ! jar -tf webbooks.jar >/dev/null 2>&1; then
                                echo "ERROR: Скачанный файл не является JAR-архивом"
                                echo "Тип файла:"
                                file webbooks.jar
                                echo "Начало файла:"
                                head -c 100 webbooks.jar
                                exit 1
                            fi
                            
                            echo "Артефакт успешно скачан и проверен"
                        """
                    }
                    
                    env.ACTUAL_ARTIFACT_PATH = "${pwd()}/webbooks.jar"
                }
            }
        }
        
        // Остальные стадии (Deploy, Verify) остаются без изменений
        // ...
    }
    
    post {
        always {
            cleanWs()
            // ...
        }
    }
}
