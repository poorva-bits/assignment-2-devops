pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    parameters {
        booleanParam(
            name: 'SIMULATE_BAD_DEPLOY',
            defaultValue: false,
            description: 'Deploy a non-existent image tag to demonstrate the automatic rollback'
        )
    }

    environment {
        DOCKERHUB_USER = 'YOUR_DOCKERHUB_USER'
        IMAGE          = "${DOCKERHUB_USER}/assignment-2-devops"
        TAG            = "build-${BUILD_NUMBER}"
        DEPLOYMENT     = 'assignment-2-devops-rolling'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Clean Build') {
            steps {
                sh '''
                    rm -rf .venv
                    python3 -m venv .venv
                    .venv/bin/pip install --upgrade pip
                    .venv/bin/pip install -r requirements.txt
                    .venv/bin/python -m py_compile app.py
                '''
            }
        }

        stage('Unit Tests + Coverage') {
            steps {
                sh '.venv/bin/python -m pytest -q --junitxml=report.xml --cov=app --cov-report=xml:coverage.xml'
            }
            post {
                always {
                    junit 'report.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    scannerHome = tool 'SonarScanner'
                }
                withSonarQubeEnv('sonarqube') {
                    sh "${scannerHome}/bin/sonar-scanner"
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t ${IMAGE}:${TAG} -t ${IMAGE}:latest .'
            }
        }

        stage('Tests inside Container') {
            steps {
                sh 'docker run --rm ${IMAGE}:${TAG} python -m pytest -q'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push ${IMAGE}:${TAG}
                        docker push ${IMAGE}:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes (rolling update + rollback)') {
            steps {
                script {
                    // First run only: create the Deployment and Service from the manifest
                    sh 'kubectl get deployment ${DEPLOYMENT} || kubectl apply -f k8s/rolling.yaml'

                    def newImage = params.SIMULATE_BAD_DEPLOY ? "${IMAGE}:does-not-exist" : "${IMAGE}:${TAG}"
                    try {
                        sh "kubectl set image deployment/${DEPLOYMENT} assignment-2-devops=${newImage}"
                        sh "kubectl rollout status deployment/${DEPLOYMENT} --timeout=90s"
                        sh '''kubectl exec deploy/${DEPLOYMENT} -- python -c "import urllib.request as u; print(u.urlopen('http://localhost:5000/health').read().decode())"'''
                    } catch (err) {
                        echo 'Deployment failed - rolling back to the last stable version'
                        sh "kubectl rollout undo deployment/${DEPLOYMENT}"
                        sh "kubectl rollout status deployment/${DEPLOYMENT} --timeout=90s"
                        error('Deployment failed and was rolled back')
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully'
        }
        failure {
            echo 'Pipeline failed - see the failing stage above'
        }
    }
}
