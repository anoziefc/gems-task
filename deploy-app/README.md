# 🚀 Secure App Deployment Behind Traefik

Setup and deployment process for running a web application securely behind the [Traefik](https://traefik.io/) reverse proxy with HTTPS enabled via Let's Encrypt.

---

## 📌 Overview

The application is containerized and deployed behind **Traefik**, which handles:

* HTTPS termination (via Let's Encrypt)
* HTTP-to-HTTPS redirection
* Dynamic routing via Docker labels
* Basic authentication (optional)

---

## 📁 Project Structure

```
├── docker-compose.yml         # Main Compose file (app + Traefik)
├── deploy.sh                  # Deployment script
└── README.md                  # This file
```

---

## ✅ Prerequisites

* Docker + Docker Compose installed
* Domain name pointing to your server (e.g., `yourdomain.com`)
* Ports 80 and 443 open in your firewall
* DNS A/AAAA record configured
* CI/CD pipeline (optional) with credentials configured
* Traefic Setup Using initial traffic setup

---

## 🔐 Security Features

* **HTTPS** enabled via **Let’s Encrypt**
* **Traefik dashboard** secured with **Basic Auth**
* **Containers run as non-root** where applicable

---

## ⚙️ Deployment Process

### Step 1: App Labels in `docker-compose.yml`

```yaml
services:
  app:
    image: docker image
    container_name: container-name
    restart: unless-stopped
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.awesome-compose-web.rule=Host(`yourdomain.com`)"
      - "traefik.http.routers.awesome-compose-web.entrypoints=websecure"
      - "traefik.http.routers.awesome-compose-web.tls.certresolver=letsencrypt"
      - "traefik.http.services.awesome-compose-web.loadbalancer.server.port=5000"
    networks: 
        traefik:
            external: true
```
---

### Step 2: Deployment via `deploy.sh`

```bash
#!/bin/bash
# Deployment script for container with Traefik

set -e

# Configuration
ENVIRONMENT=${1:-production}
IMAGE_TAG=${2:-latest}
APP_NAME="your-app-name"
COMPOSE_FILE="docker-compose.yml"
NETWORK_NAME="traefik"
DOMAIN="your domain name"

# Docker registry configuration
REGISTRY="docker username"
IMAGE_NAME="${REGISTRY}/${APP_NAME}:${IMAGE_TAG}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running or not accessible"
    fi
    log "Docker is running"
}

# Create Traefik network if it doesn’t exist
create_network() {
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        log "Creating Traefik network: $NETWORK_NAME"
        docker network create "$NETWORK_NAME"
    else
        log "Traefik network already exists: $NETWORK_NAME"
    fi
}

# Deploy new container
deploy_container() {
    log "Deploying new container: $APP_NAME"
    docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

    if [ $? -eq 0 ]; then
        log "Container deployed successfully: $APP_NAME"
        log "Application will be available at: https://$DOMAIN"
    else
        error "Failed to deploy container"
    fi
}

# Health check
health_check() {
    log "Performing health check…"
    sleep 10
    if ! docker ps --format 'table {{.Names}}' | grep -q "^${APP_NAME}$"; then
        error "Container is not running after deployment"
    fi

    log "Container logs (last 10 lines):"
    docker logs --tail 10 "$APP_NAME"
    log "Health check completed"
}

# Cleanup old images
cleanup_images() {
    log "Cleaning up old images…"
    docker image prune -f
    log "Image cleanup completed"
}

# Main deployment process
main() {
    log "Starting deployment process…"
    log "Environment: $ENVIRONMENT"
    log "Image: $IMAGE_NAME"
    log "Domain: $DOMAIN"

    check_docker
    create_network
    deploy_container
    health_check
    cleanup_images

    log "Deployment completed successfully!"
    log "Application is available at: https://$DOMAIN"
}

# Run main function
main "$@"
```

Make the script executable:

```bash
chmod +x deploy.sh
```

---

### Step 3: Trigger from CI/CD (Optional)

In **Jenkins**, use a `post-build` or `deploy` stage:

```groovy
stage('Deploy to Server') {
    steps {
        sshagent(['deploy-key']) {
            sh 'ssh user@yourserver "cd /path/to/project && ./deploy.sh"'
        }
    }
}
```

---

## 🔎 Verification

* Navigate to **[https://app.yourdomain.com](https://app.yourdomain.com)**
* Check that the certificate is valid (Let’s Encrypt)
* Confirm redirection from HTTP to HTTPS
* (Optional) Visit Traefik dashboard at `https://traefik.yourdomain.com` with basic auth

---

## 📓 Notes

* Use Let’s Encrypt **staging** endpoint during initial testing to avoid rate limits.
* Ensure **UFW/iptables** allow ports 80 and 443.
* Use **Jenkins credentials manager** to handle SSH keys or Docker credentials securely.
* Optionally persist logs and certs outside containers for durability.
