#!/bin/bash
# Deployment script for container with Traefik

set -e

# Configuration
ENVIRONMENT=${1:-production}
IMAGE_TAG=${2:-latest}
APP_NAME="awesome-compose-web"
COMPOSE_FILE="docker-compose.yml"
NETWORK_NAME="traefik"
DOMAIN="${APP_NAME}.duckdns.org"

# Docker registry configuration
REGISTRY="afanozie"
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