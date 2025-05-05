pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target server IP', defaultValue: '10.130.0.24')
        string(name: 'DEPLOY_PATH', description: 'Deployment directory', defaultValue: '/opt/webbooks')
        string(name: 'SOURCE_JOB', description: 'Source job name', defaultValue: 'Webbooks-Multibranch/main')
        string(name: 'ARTIFACT_PATH', description: 'Artifact path', defaultValue: 'apps/webbooks/target/webbooks.jar')
    }
    
    environment {
        SERVICE_NAME = 'webbooks'
        JENKINS_URL = 'http://158.160.184.242:8080/'
    }
    
    stages {
        stage('Get Artifact') {
            steps {
                script {
                    // Ожидаем завершения сборки и получаем информацию
                    def buildInfo = build(
                        job: params.SOURCE_JOB,
                        propagate: false,
                        wait: true,
                        parameters: []
                    )
                    
                    if (buildInfo.result != 'SUCCESS') {
                        error "Сборка ${params.SOURCE_JOB} завершилась со статусом ${buildInfo.result}"
                    }
                    
                    // Формируем корректный URL для многоуровневых job
                    def jobPath = params.SOURCE_JOB.replace('/', '/job/')
                    def artifactUrl = "${env.JENKINS_URL}job/${jobPath}/${buildInfo.number}/artifact/${params.ARTIFACT_PATH}"
                    
                    echo "Скачиваем артефакт из: ${artifactUrl}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'jenkins-api-token',
                        usernameVariable: 'JENKINS_USER',
                        passwordVariable: 'JENKINS_TOKEN'
                    )]) {
                        sh """
                            # Скачиваем артефакт с подробным логом
                            curl -v -sSL -u "$JENKINS_USER:$JENKINS_TOKEN" -o webbooks.jar "${artifactUrl}"
                            
                            # Проверяем, что файл скачан
                            if [ ! -f "webbooks.jar" ]; then
                                echo "ERROR: Файл артефакта не был скачан"
                                exit 1
                            fi
                            
                            # Проверяем размер файла
                            filesize=\$(stat -c%s webbooks.jar)
                            echo "Размер файла: \${filesize} байт"
                            
                            if [ "\$filesize" -lt 10000 ]; then
                                echo "ERROR: Размер файла слишком мал (\${filesize} bytes), возможно ошибка загрузки"
                                echo "Первые 100 байт файла:"
                                xxd -l 100 webbooks.jar
                                exit 1
                            fi
                            
                            # Проверяем, что это валидный JAR-файл
                            if ! jar -tf webbooks.jar >/dev/null
