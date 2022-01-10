pipeline {
  agent any
  stages {
    stage('docker') {
      steps {
        sh 'sudo docker build -f Dockerfile .'
      }
    }

  }
}