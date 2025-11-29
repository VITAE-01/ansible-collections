def repoName = ''
def branchName = ''

pipeline {
    agent any

    environment {
        NEXUS_USER = credentials('NEXUS_USER')
        NEXUS_PASS = credentials('NEXUS_PASS')
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
                anyOf {
                    branch 'PR-*'
                    expression {
                        return branchName == 'Dev'
                    }
                }
            }
            steps {
                script {
                    echo "Publishing Ansible collections to Github Release and Nexus repository for repo: ${repoName} - branch: ${branchName}"
                    dir('ansible-collections') {
                        
                    }
                    
                }
            }
        }

        stage('Auth dry run') {
            when {
                expression {
                    return branchName == 'Dev'
                }
            }
            steps {
                script {
                    echo "Performing auth dry run for repo: ${repoName} - branch: ${branchName}"

                    sh """
                        echo "Performing dry run with the following credentials:"
                        gh auth status
                    """
                    sh """
                        echo "NEXUS_REPO_URL: $NEXUS_REPO_URL"
                    """
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
    }
}