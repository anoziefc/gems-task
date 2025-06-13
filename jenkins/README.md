# 🚀 Jenkins CI Pipeline with Docker, Traefik, and GitHub/Docker Hub Integration

This project sets up a **Jenkins CI/CD pipeline** running in Docker behind a **Traefik reverse proxy** (TLS-enabled), to build and push Docker images from a GitHub repository to either **Docker Hub**.

---

## 📦 Features

* Jenkins installed via Docker
* Exposed securely via Traefik with TLS
* CI pipeline:
  * Clones code from GitHub
  * Builds Docker image
  * Pushes image to Docker Hub or GHCR
* Jenkins Credentials Manager integration for secrets
* Docker-in-Docker (DinD) support for building images
* Hardened Jenkins setup for production safety

---

## 🛠️ Requirements

* Docker & Docker Compose
* A domain name (e.g. `ci.example.com`)
* Traefik configured for TLS (Let’s Encrypt)
* Jenkins credentials for:

  * GitHub access
  * Docker Hub

---

## 📁 Project Structure

```bash
.
├── docker-compose.yml
├── init.groovy.d
│   └── basic-security.groovy
├── Dockerfile
├── plugins.txt
├── Jenkinsfile
└── README.md
```

---

## ⚙️ Jenkins Setup via Docker & Traefik
* **Docker and Traefik Already installed in previous setup**
* **TLS already configured using Let's Encrypt**

# Jenkins/Dockerfile
```Dockerfile
FROM jenkins/jenkins:latest

USER root

RUN apt-get update && apt-get install -y docker.io

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

USER jenkins
```

# Jenkins/docker-compose.yml
```yaml
---

services:
  jenkins:
    build: .
    container_name: jenkins
    user: root
    restart: unless-stopped
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      JAVA_OPTS: "-Djenkins.install.runSetupWizard=false"
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jenkins.rule=Host(`your-jenkins-domain.com`)"
      - "traefik.http.routers.jenkins.entrypoints=websecure"
      - "traefik.http.routers.jenkins.tls.certresolver=letsencrypt"
      - "traefik.http.services.jenkins.loadbalancer.server.port=8080"

volumes:
  jenkins_home:

networks:
  traefik:
    external: true

```

# Jenkins/init.groovy.d/basic-security.groovy
```groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.get()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()

```

```Jenkinsfile
pipeline {
    agent any

    environment {
        IMAGE = 'docker-hub-username/image-name'
        TAG = "${env.BUILD_NUMBER}" ## Uses the jenkins build number to version your build 
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '1'))
        disableConcurrentBuilds()
    }

    stages {
         stage('Clone Repository') {
            steps {
                sh 'rm -rf awesome-compose'
                sh 'git clone https://github.com/anoziefc/gems-task-test-repo.git'
            }
        }
        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'your-credential-id', usernameVariable: 'Username', passwordVariable: 'Password')]) {
                    sh 'echo $Password | docker login -u $Username --password-stdin'
                }
            }
        }
        stage('Docker Build') {
            steps {
                dir('gems-task-test-repo') {
                    sh """
                        docker build -t ${IMAGE}:${TAG} .
                        docker tag ${IMAGE}:${TAG} ${IMAGE}:latest
                    """
                }
            }
        }
        stage('Docker Push') {
            steps {
                sh """
                    docker push ${IMAGE}:${TAG}
                    docker push ${IMAGE}:latest
                """
            }
        }
        stage('Cleanup') {
            steps {
                sh 'docker system prune -af'
            }
        }  
    }

    post {
        always {
            sh 'docker logout || true'
        }
    }
}

```
---

## 🔐 Security Hardening Notes

| Area                | Strategy                                                                          |
| ------------------- | --------------------------------------------------------------------------------- |
| **TLS**             | Use Traefik with Let’s Encrypt or custom certificates for encrypted HTTP (HTTPS)  |
| **Admin Access**    | Disable Jenkins default admin account after initial setup                         |
| **Credentials**     | Store GitHub/Docker secrets using Jenkins Credentials Manager; never hardcode     |
| **Firewall**        | Expose only Traefik to public; restrict Docker and Jenkins ports to local network |
| **Updates**         | Use Jenkins LTS version; apply plugin updates regularly                           |
| **Plugins**         | Install only necessary, verified plugins                                          |
| **CSRF & Headers**  | Enable CSRF protection and strict Content Security Policy (CSP) headers           |
| **Backups**         | Regularly backup `jenkins_home` volume                                            |
| **Least Privilege** | Run Jenkins and Docker with the minimal permissions required                      |

---

## 📤 Push Targets

This pipeline supports:

* Docker Hub: `docker.io/yourusername/yourimage`

Make sure your credentials match the registry and that the Jenkins node has access.

---

## 📎 Tips

* Ensure Docker socket is mounted securely. Prefer remote Docker host (TLS-protected) in production.
