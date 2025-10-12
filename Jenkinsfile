pipeline {
    agent any
    
    environment {
        NEXUS_DOCKER_REPO = 'http://34.239.182.154:8081/repository/hub.aceternity'
        NEXUS_RAW_REPO = 'http://34.239.182.154:8081/repository/raw.acertenity'
        ARTIFACT_NAME = 'springboot-demo'
        DOCKER_IMAGE_NAME = 'springboot-demo'
    }
    
    stages {
        stage('Checkout & Tag Management') {
            steps {
                script {
                    // Checkout du code depuis la branche main
                    checkout scm
                    
                    // Récupérer le hash du dernier commit de main
                    def lastCommitHash = sh(
                        script: "git rev-parse HEAD",
                        returnStdout: true
                    ).trim()
                    
                    echo "Dernier commit de main: ${lastCommitHash}"
                    
                    // Vérifier si ce commit a déjà un tag
                    def existingTag = sh(
                        script: "git tag --points-at ${lastCommitHash}",
                        returnStdout: true
                    ).trim()
                    
                    if (existingTag) {
                        echo "Le commit ${lastCommitHash} est déjà tagué avec: ${existingTag}"
                        env.CURRENT_TAG = existingTag
                        env.NEW_TAG_CREATED = 'false'
                    } else {
                        echo "Le commit ${lastCommitHash} n'est pas tagué. Création d'un nouveau tag..."
                        
                        // Récupérer le dernier tag existant
                        def lastTag = sh(
                            script: "git describe --tags --abbrev=0 2>/dev/null || echo ''",
                            returnStdout: true
                        ).trim()
                        
                        if (!lastTag) {
                            // Premier tag du projet
                            env.CURRENT_TAG = '1.0-SNAPSHOT-1'
                            echo "Premier tag du projet: ${env.CURRENT_TAG}"
                        } else {
                            echo "Dernier tag existant: ${lastTag}"
                            
                            // Extraire le numéro de version et l'incrémenter
                            def tagPattern = /(\d+)\.(\d+)-SNAPSHOT-(\d+)/
                            def matcher = lastTag =~ tagPattern
                            
                            if (matcher.matches()) {
                                def major = matcher[0][1] as Integer
                                def minor = matcher[0][2] as Integer
                                def patch = matcher[0][3] as Integer
                                
                                env.CURRENT_TAG = "${major}.${minor}-SNAPSHOT-${patch + 1}"
                                echo "Nouveau tag créé: ${env.CURRENT_TAG}"
                            } else {
                                // Si le format ne correspond pas, créer un tag par défaut
                                env.CURRENT_TAG = '1.0-SNAPSHOT-1'
                                echo "Format de tag non reconnu, création d'un tag par défaut: ${env.CURRENT_TAG}"
                            }
                        }
                        
                        // Créer et pusher le nouveau tag
                        sh "git tag ${env.CURRENT_TAG}"
                        sh "git push origin ${env.CURRENT_TAG}"
                        env.NEW_TAG_CREATED = 'true'
                        echo "Tag ${env.CURRENT_TAG} créé et poussé vers Git"
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                echo "Exécution des tests unitaires avec Maven..."
                sh "sed -i 's/<version>0.0.1-SNAPSHOT<\\/version>/<version>${env.CURRENT_TAG}<\\/version>/' pom.xml"
                sh "./mvnw clean test"
            }
        }
        
        stage('Build Application') {
            steps {
                echo "Build de l'application avec Maven..."
                script {
                    sh "./mvnw package -DskipTests"
                }
            }
        }
        
        stage('Package & Archive') {
            steps {
                script {
                    // Créer le répertoire de packaging
                    sh "mkdir -p target/packaging"
                    
                    // Copier le JAR dans le répertoire de packaging
                    sh "cp target/${ARTIFACT_NAME}-${env.CURRENT_TAG}.jar target/packaging/"
                    
                    // Créer l'archive ZIP
                    sh "cd target/packaging && zip -r ../${ARTIFACT_NAME}-${env.CURRENT_TAG}.zip ."
                    
                    // Archiver l'artifact pour Jenkins
                    archiveArtifacts artifacts: "target/${ARTIFACT_NAME}-${env.CURRENT_TAG}.zip", fingerprint: true
                    
                    echo "Package créé: ${ARTIFACT_NAME}-${env.CURRENT_TAG}.zip"
                }
            }
        }
        
        stage('Push to Nexus Raw Repository') {
            steps {
                script {
                    echo "Poussage du package vers Nexus Raw Repository..."
                    
                    withCredentials([usernamePassword(credentialsId: 'nexus_creds', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                        def nexusResult = sh(
                            script: """
                                curl -v -u \${USERNAME}:\${PASSWORD} \\
                                --fail \\
                                --upload-file target/${ARTIFACT_NAME}-${env.CURRENT_TAG}.zip \\
                                ${NEXUS_RAW_REPO}/${env.CURRENT_TAG}/${ARTIFACT_NAME}-${env.CURRENT_TAG}.zip
                            """,
                            returnStatus: true
                        )
                        
                        if (nexusResult != 0) {
                            error "ÉCHEC: Push vers Nexus Raw Repository a échoué!"
                        } else {
                            echo " SUCCÈS: Package poussé vers Nexus: ${NEXUS_RAW_REPO}/${env.CURRENT_TAG}/"
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "Construction de l'image Docker..."
                    
                    def dockerResult = sh(
                        script: """
                            docker build -t ${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG} -t ${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG} .
                        """,
                        returnStatus: true
                    )
                    
                    if (dockerResult != 0) {
                        error "ÉCHEC: Construction de l'image Docker a échoué"
                    } else {
                        echo "SUCCÈS: Image Docker construite: ${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG}"
                    }
                }
            }
        }
        
        stage('Push Docker Image to Nexus') {
            steps {
                script {
                    echo "Poussage de l'image Docker vers Nexus..."
                    
                    withCredentials([usernamePassword(credentialsId: 'nexus_creds', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                        def dockerPushResult = sh(
                            script: """
                                echo \${PASSWORD} | docker login 34.239.182.154:8081 -u \${USERNAME} --password-stdin
                                
                                docker tag ${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG} 34.239.182.154:8081/hub.aceternity/${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG}
                                
                                docker push 34.239.182.154:8081/hub.aceternity/${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG}
                                
                                docker logout 34.239.182.154:8081
                            """,
                            returnStatus: true
                        )
                        
                        if (dockerPushResult != 0) {
                            error "ÉCHEC: Push de l'image Docker vers Nexus a échoué "
                        } else {
                            echo "SUCCÈS: Image Docker poussée vers Nexus: ${NEXUS_DOCKER_REPO}/${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG}"
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            // Nettoyage des images Docker locales pour économiser l'espace
            sh "docker rmi ${DOCKER_IMAGE_NAME}:${env.CURRENT_TAG} || true"
        }
    }
}
