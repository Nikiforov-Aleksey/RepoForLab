pipeline {
    agent any

    tools {
        maven '3.2.5'
        jdk 'jdk17'
    }

    environment {
        DB_URL = credentials('db-url')
        S3_BUCKET = 'webbooks-artifacts'
        TF_STATE_BUCKET = 'webbooks-tf-state'
        TF_VARS_FILE = 'infrastructure/terraform.tfvars'
        NOTIFICATION_WEBHOOK = credentials('slack-webhook')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${env.GIT_BRANCH}"]],
                    extensions: [[
                        $class: 'CleanBeforeCheckout'
                    ]],
                    userRemoteConfigs: [[
                        url: 'https://github.com/your-repo/webbooks.git',
                        credentialsId: 'github-credentials'
                    ]]
                ])
            }
        }

        stage('Code Quality') {
            when {
                anyOf {
                    branch 'PR-*'
                    branch 'main'
                }
            }
            steps {
                dir('apps/webbooks') {
                    sh 'mvn checkstyle:checkstyle pmd:pmd'
                    recordIssues(
                        tools: [
                            checkStyle(pattern: '**/checkstyle-result.xml'),
                            pmdParser(pattern: '**/pmd.xml')
                        ]
                    )
                }
            }
        }

        stage('Build and Test') {
            steps {
                dir('apps/webbooks') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'webbooks-db-creds',
                            usernameVariable: 'DB_USER',
                            passwordVariable: 'DB_PASS'
                        ),
                        file(
                            credentialsId: 'yandex-cloud-key',
                            variable: 'YC_KEY'
                        )
                    ]) {
                        sh """
                            mvn --batch-mode clean package \
                            -DDB.url=${DB_URL} \
                            -DDB.username=${DB_USER} \
                            -DDB.password=${DB_PASS}
                            
                            # Проверка артефакта
                            jar -tf target/DigitalLibrary-*.jar > /dev/null
                            
                            # Создание уникального имени артефакта
                            ARTIFACT_VERSION=\$(date +%Y%m%d%H%M%S)
                            cp target/DigitalLibrary-*.jar target/webbooks-\${ARTIFACT_VERSION}.jar
                            
                            # Загрузка в S3
                            aws s3 cp target/webbooks-\${ARTIFACT_VERSION}.jar \
                              s3://${S3_BUCKET}/artifacts/webbooks-\${ARTIFACT_VERSION}.jar
                            
                            # Сохранение версии для деплоя
                            echo "ARTIFACT_VERSION=\${ARTIFACT_VERSION}" > .artifact_version
                        """
                    }
                }
            }
        }

        stage('Terraform Plan') {
            when {
                branch 'main'
            }
            steps {
                dir('infrastructure') {
                    withCredentials([file(
                        credentialsId: 'yandex-cloud-key',
                        variable: 'YC_KEY'
                    )]) {
                        sh '''
                            terraform init -backend-config="bucket=${TF_STATE_BUCKET}" \
                                          -backend-config="key=terraform.tfstate"
                            terraform plan -var-file=${TF_VARS_FILE}
                        '''
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
                expression {
                    currentBuild.result == null || currentBuild.result == 'SUCCESS'
                }
            }
            steps {
                dir('infrastructure') {
                    withCredentials([file(
                        credentialsId: 'yandex-cloud-key',
                        variable: 'YC_KEY'
                    )]) {
                        sh '''
                            terraform apply -auto-approve -var-file=${TF_VARS_FILE}
                        '''
                    }
                }
                
                script {
                    def frontend_url = sh(
                        script: 'terraform output -raw frontend_url',
                        returnStdout: true
                    ).trim()
                    
                    // Отправка уведомления
                    slackSend(
                        color: 'good',
                        message: "Deployment successful!\nFrontend: ${frontend_url}\nBuild: ${env.BUILD_URL}"
                    )
                }
            }
        }
    }

    post {
        always {
            script {
                if (currentBuild.result == 'FAILURE') {
                    slackSend(
                        color: 'danger',
                        message: "Build failed!\nBuild: ${env.BUILD_URL}"
                    )
                }
            }
        }
    }
}
