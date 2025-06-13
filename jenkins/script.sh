
#!/bin/bash

set -e

echo "🚀 Setting up Jenkins CI/CD Pipeline with Docker and Traefik"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create directory structure
print_status "Creating directory structure..."
mkdir -p jenkins/
mkdir -p traefik/
mkdir -p certs/

# Set proper permissions for certificates directory
chmod 600 certs/ 2>/dev/null || true

# Create plugins.txt file
print_status "Creating Jenkins plugins configuration..."
cat > jenkins/plugins.txt << EOF
workflow-aggregator:latest
pipeline-stage-view:latest
git:latest
github:latest
docker-plugin:latest
docker-workflow:latest
credentials:latest
credentials-binding:latest
blue-ocean:latest
build-timeout:latest
timestamper:latest
ws-cleanup:latest
EOF

# Create initial Jenkins configuration
print_status "Creating Jenkins initial configuration..."
cat > jenkins/jenkins.yaml << EOF
jenkins:
  systemMessage: "Jenkins configured with Configuration as Code"
  numExecutors: 2
  mode: NORMAL
  scmCheckoutRetryCount: 3
  
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "admin123"
          
  authorizationStrategy:
    globalMatrix:
      permissions:
        - "Overall/Administer:admin"
        - "Overall/Read:authenticated"

  nodes:
    - permanent:
        name: "docker-agent"
        remoteFS: "/home/jenkins/agent"
        launcher:
          inbound:
            webSocket: true

unclassified:
  location:
    url: "https://gemsjenkins.duckdns.org"

EOF

# Create environment file
print_status "Creating environment configuration..."
cat > .env << EOF
# Jenkins Configuration
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=admin123
JENKINS_AGENT_SECRET=my-secret-key

# Domain Configuration (replace with your actual domains)
JENKINS_DOMAIN=gemsjenkins.duckdns.org
TRAEFIK_DOMAIN=gemstraefic.duckdns.org/

# Email for Let's Encrypt
ACME_EMAIL=cfanozie@gmail.com

# Docker Registry Configuration
DOCKERHUB_USERNAME=afanozie
EOF

print_warning "Please update the .env file with your actual configuration values!"

# Create sample Dockerfile for testing
print_status "Creating sample application for testing..."
mkdir -p sample-app/

cat > sample-app/Dockerfile << EOF
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy static files
COPY src/ /usr/share/nginx/html/

# Add metadata
LABEL maintainer="cfanozie@gmail.com"
LABEL version="1.0"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

mkdir -p sample-app/src/
cat > sample-app/src/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Sample CI/CD App</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .success { color: #4CAF50; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="success">🚀 CI/CD Pipeline Success!</h1>
        <p>This application was built and deployed using Jenkins CI/CD pipeline.</p>
        <p>Build: <strong>{{BUILD_NUMBER}}</strong></p>
        <p>Commit: <strong>{{GIT_COMMIT}}</strong></p>
        <p>Timestamp: <strong>{{BUILD_TIMESTAMP}}</strong></p>
    </div>
</body>
</html>
EOF

cat > sample-app/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    sendfile        on;
    keepalive_timeout  65;
    
    server {
        listen       80;
        server_name  localhost;
        
        location / {
            root   /usr/share/nginx/html;
            index  index.html;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Create startup script
cat > start.sh << 'EOF'
#!/bin/bash

echo "Starting Jenkins CI/CD environment..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | awk '/=/ {print $1}')
fi

# Start services
docker-compose up -d

echo "Waiting for services to start..."
sleep 30

echo "Services started successfully!"
echo ""
echo "Access URLs:"
echo "- Jenkins: https://gemsjenkins.duckdns.org"
echo "- Traefik Dashboard: https://gemstraefic.duckdns.org/"
echo ""
echo "Default Jenkins credentials:"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "Please check the logs if services are not accessible:"
echo "docker-compose logs jenkins"
echo "docker-compose logs traefik"
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash
echo "Stopping Jenkins CI/CD environment..."
docker-compose down
echo "Environment stopped."
EOF

chmod +x stop.sh

# Set proper permissions
chmod 600 certs/ 2>/dev/null || true
chown -R 1000:1000 jenkins/ 2>/dev/null || true

print_success "Setup completed successfully!"
print_status "Next steps:"
echo "1. Update the .env file with your domain and email configuration"
echo "2. Update docker-compose.yml with your domain names"
echo "3. Run './start.sh' to start the services"
echo "4. Access Jenkins and configure credentials for Docker Hub/GitHub"
echo "5. Create a new pipeline job and use the provided Jenkinsfile"
echo ""
print_warning "Security Notes:"
echo "- Change default Jenkins admin password immediately"
echo "- Configure proper authentication (LDAP/OAuth)"
echo "- Set up proper firewall rules"
echo "- Use strong secrets for Jenkins agent"
echo "- Regularly update Docker images"
