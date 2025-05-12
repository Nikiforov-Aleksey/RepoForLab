pipeline {
    agent any

    tools {
        maven '3.2.5'
        
    }

    environment {
        DB_URL = credentials('db-url')
        S3_BUCKET = 'webbooks-artifacts'
        TF_STATE_BUCKET = 'webbooks-tf-state'
        TF_VARS_FILE = 'infrastructure/terraform.tfvars'
        SLACK_WEBHOOK = credentials('slack-webhook')
        PROMETHEUS_URL = 'http://monitoring:9090'
        LOKI_URL = 'http://monitoring:3100'
        GRAFANA_URL = 'http://monitoring:3000'
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
                    branch 'develop'
                }
            }
            steps {
                dir('apps/webbooks') {
                    sh 'mvn checkstyle:checkstyle pmd:pmd spotbugs:spotbugs'
                    recordIssues(
                        tools: [
                            checkStyle(pattern: '**/checkstyle-result.xml'),
                            pmdParser(pattern: '**/pmd.xml'),
                            spotBugs(pattern: '**/spotbugsXml.xml')
                        ],
                        qualityGates: [
                            [threshold: 1, type: 'TOTAL', unstable: true]
                        ]
                    )
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('apps/webbooks') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'webbooks-db-creds',
                            usernameVariable: 'DB_USER',
                            passwordVariable: 'DB_PASS'
                        )
                    ]) {
                        sh """
                            mvn --batch-mode test \
                            -DDB.url=${DB_URL} \
                            -DDB.username=${DB_USER} \
                            -DDB.password=${DB_PASS}
                        """
                    }
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Integration Tests') {
            when {
                anyOf {
                    branch 'PR-*'
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                dir('apps/webbooks') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'webbooks-db-creds',
                            usernameVariable: 'DB_USER',
                            passwordVariable: 'DB_PASS'
                        )
                    ]) {
                        sh """
                            mvn --batch-mode verify -Pintegration-test \
                            -DDB.url=${DB_URL} \
                            -DDB.username=${DB_USER} \
                            -DDB.password=${DB_PASS}
                        """
                    }
                    junit '**/target/failsafe-reports/*.xml'
                }
            }
        }

        stage('Build Artifact') {
            steps {
                dir('apps/webbooks') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'webbooks-db-creds',
                            usernameVariable: 'DB_USER',
                            passwordVariable: 'DB_PASS'
                        )
                    ]) {
                        sh """
                            mvn --batch-mode clean package \
                            -DskipTests \
                            -DDB.url=${DB_URL} \
                            -DDB.username=${DB_USER} \
                            -DDB.password=${DB_PASS}
                            
                            # Проверка артефакта
                            jar -tf target/DigitalLibrary-*.jar > /dev/null
                            
                            # Создание уникального имени артефакта
                            ARTIFACT_VERSION=\$(git rev-parse --short HEAD)-\$(date +%Y%m%d%H%M%S)
                            cp target/DigitalLibrary-*.jar target/webbooks-\${ARTIFACT_VERSION}.jar
                            
                            # Сохранение версии для деплоя
                            echo "ARTIFACT_VERSION=\${ARTIFACT_VERSION}" > .artifact_version
                        """
                    }
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }

        stage('Upload to S3') {
            when {
                anyOf {
                    branch 'main'
                    branch 'release/*'
                }
            }
            steps {
                dir('apps/webbooks') {
                    withCredentials([file(
                        credentialsId: 'yandex-s3-credentials',
                        variable: 'AWS_CREDS'
                    )]) {
                        sh '''
                            source .artifact_version
                            aws s3 cp target/webbooks-${ARTIFACT_VERSION}.jar \
                              s3://${S3_BUCKET}/artifacts/webbooks-${ARTIFACT_VERSION}.jar
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            when {
                anyOf {
                    branch 'PR-*'
                    branch 'main'
                    branch 'develop'
                }
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

        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                dir('infrastructure') {
                    withCredentials([file(
                        credentialsId: 'yandex-cloud-key',
                        variable: 'YC_KEY'
                    )]) {
                        sh '''
                            terraform workspace select staging || terraform workspace new staging
                            terraform apply -auto-approve -var-file=${TF_VARS_FILE} -var="environment=staging"
                        '''
                    }
                }
                
                script {
                    def frontend_url = sh(
                        script: 'terraform output -raw frontend_url',
                        returnStdout: true
                    ).trim()
                    
                    slackSend(
                        channel: '#ci-cd',
                        color: 'good',
                        message: "Staging deployment successful!\nFrontend: ${frontend_url}\nBuild: ${env.BUILD_URL}"
                    )
                }
            }
        }

        stage('Deploy to Production') {
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
                            terraform workspace select production || terraform workspace new production
                            terraform apply -auto-approve -var-file=${TF_VARS_FILE} -var="environment=production"
                        '''
                    }
                }
                
                script {
                    def frontend_url = sh(
                        script: 'terraform output -raw frontend_url',
                        returnStdout: true
                    ).trim()
                    
                    slackSend(
                        channel: '#ci-cd',
                        color: 'good',
                        message: "Production deployment successful!\nFrontend: ${frontend_url}\nBuild: ${env.BUILD_URL}"
                    )
                }
            }
        }

        stage('Monitoring Setup') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                dir('infrastructure') {
                    withCredentials([file(
                        credentialsId: 'yandex-cloud-key',
                        variable: 'YC_KEY'
                    )]) {
                        sh '''
                            # Настройка мониторинга
                            ansible-playbook -i inventory.ini monitoring/setup.yml
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (currentBuild.result == 'FAILURE') {
                    slackSend(
                        channel: '#ci-cd',
                        color: 'danger',
                        message: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n${env.BUILD_URL}"
                    )
                }
                
                // Очистка workspace
                cleanWs()
            }
        }
        success {
            script {
                if (env.GIT_BRANCH == 'main' || env.GIT_BRANCH == 'develop') {
                    // Отправка метрик в Prometheus
                    sh """
                        curl -X POST "${PROMETHEUS_URL}/api/v1/import/prometheus" \
                          --data-raw "deployment_success{application=\"webbooks\", environment=\"${env.GIT_BRANCH == 'main' ? 'production' : 'staging'}\"} 1"
                    """
                }
            }
        }
    }
}
