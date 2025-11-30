def repoName = ''
def branchName = ''

pipeline {
    agent any

    environment {
        NEXUS_REPO_URL = credentials('NEXUS_REPO_URL')
        GITHUB_TOKEN = credentials('GITHUB_TOKEN')
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        stage('Initialize variables') {
            steps {
                script {
                    repoName = env.GIT_URL?.tokenize('/').last()?.replace('.git', '')
                    branchName = env.GIT_BRANCH?.replaceFirst(/^origin\//, '')
                }
            }
        }

        stage('Checkout Repositories') {
            when {
                anyOf {
                    branch 'PR-*'
                    expression {
                        return branchName == 'Dev'
                    }
                }
            }
            steps {
                script {
                    echo "Checking out the source code from the repository: ${repoName} - branch: ${branchName}"
                    dir('ansible-collections') {
                        checkout scm
                    }
                }
            }
        }

        stage('Publish collections to github release and nexus repository') {
            when {
                expression {
                    return branchName == 'Dev'
                }
            }
            steps {
                script {
                    echo "set git user config for jenkins"
                    sh '''
                        git config --global user.email "jenkins@local"
                        git config --global user.name "jenkins"

                        git config --global credential.helper store
                        echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > ~/.git-credentials

                        git config --global --add safe.directory "/var/lib/jenkins/workspace/${JOB_NAME}"
                    '''

                    echo "Publishing Ansible collections to Github Release and Nexus repository for repo: ${repoName} - branch: ${branchName}"

                    dir('ansible-collections') {
                        withCredentials([usernamePassword(credentialsId: 'NEXUS_CREDS', passwordVariable: 'NEXUS_PASS', usernameVariable: 'NEXUS_USER')]) {
                                    sh '''
                                        chmod +x ./release.sh
                                        ./release.sh "${NEXUS_REPO_URL}" ${NEXUS_USER} ${NEXUS_PASS} "${branchName} ${repoName}"
                                    """
                        }
                    }
                    
                }
            }
        }

    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Please check the logs for details.'
        }
        aborted {
            echo 'Pipeline was aborted.'
        }
        always {
            echo 'Pipeline has finished execution.'
            cleanWs()
        }
    }
}