#!/bin/bash

# Traefik Setup Script
echo "Setting up Traefik reverse proxy..."

# Create directory structure
mkdir -p traefik traefik/logs nginx

# Create the external network
echo "Creating traefik network..."
docker network create traefik 2>/dev/null || echo "Network already exists"

# Create acme.json file for Let's Encrypt certificates
echo "Creating acme.json file..."
touch traefik/acme.json
chmod 600 traefik/acme.json
chmod 755 traefik/logs

# Generate password hash for basic auth
echo "Generating basic auth credentials..."
echo "Default credentials: admin/admin123"
echo "You can change these by editing traefik/users.txt"
sudo apt update
sudo apt install apache2-utils -y
htpasswd -nbB admin admin123 > traefik/users.txt

# Create a simple HTML file for nginx
cat > nginx/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx with Basic Auth</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .success { color: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="success">🎉 Success!</h1>
        <h2>Nginx Service with Basic Authentication</h2>
        <p>If you can see this page, you've successfully:</p>
        <ul>
            <li>✅ Authenticated with basic auth</li>
            <li>✅ Connected through Traefik reverse proxy</li>
            <li>✅ Established HTTPS connection</li>
        </ul>
        <hr>
        <p><strong>Server:</strong> Nginx</p>
        <p><strong>Proxy:</strong> Traefik</p>
        <p><strong>Security:</strong> HTTPS + Basic Auth</p>
    </div>
</body>
</html>
EOF

# Set proper permissions
chmod 644 traefik/users.txt
chmod 644 nginx/index.html

echo "Traefik setup completed successfully!"
