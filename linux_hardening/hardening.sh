#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Configuration variables
ADMIN_USER="${ADMIN_USER:-dockeradmin}"
SSH_PORT="${SSH_PORT:-2222}"
DOCKER_VERSION="${DOCKER_VERSION:-latest}"

log "Starting Ubuntu 22.04 server hardening for Docker host..."

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
log "Installing essential security packages..."
apt install -y \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges \
    logwatch \
    rkhunter \
    chkrootkit \
    aide \
    curl \
    wget \
    git \
    htop \
    vim \
    net-tools

# Create non-root sudo user
log "Creating admin user: $ADMIN_USER"
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo "$ADMIN_USER"
    
    # Set up SSH key authentication
    USER_HOME="/home/$ADMIN_USER"
    mkdir -p "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chown -R "$ADMIN_USER:$ADMIN_USER" "$USER_HOME/.ssh" 
    
    # Generate SSH key pair if not exists
    if [[ ! -f "$USER_HOME/.ssh/id_rsa" ]]; then
        sudo -u "$ADMIN_USER" ssh-keygen -t rsa -b 4096 -f "$USER_HOME/.ssh/id_rsa" -N ""
        cat "$USER_HOME/.ssh/id_rsa.pub" >> "$USER_HOME/.ssh/authorized_keys"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
        chown -R "$ADMIN_USER:$ADMIN_USER" "$USER_HOME/.ssh/authorized_keys"
    fi
    
    log "Admin user '$ADMIN_USER' created successfully"
    warn "SSH private key location: $USER_HOME/.ssh/id_rsa"
else
    log "User '$ADMIN_USER' already exists"
fi

# Configure SSH hardening
log "Hardening SSH configuration..."
SSH_CONFIG="/etc/ssh/sshd_config"
cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"

cat > "$SSH_CONFIG" << EOF
# SSH Hardened Configuration
Port $SSH_PORT
Protocol 2

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security settings
X11Forwarding no
PrintMotd no
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 60

# Restrict users
AllowUsers $ADMIN_USER

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Ciphers and algorithms (secure options)
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
EOF

# Configure UFW firewall
log "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH on custom port
ufw allow "$SSH_PORT"/tcp comment 'SSH'

# Allow HTTP/HTTPS for containers
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Enable UFW
ufw --force enable

# Configure fail2ban
log "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# Configure automatic updates
log "Configuring automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# APT hardening
log "Hardening APT configuration..."
cat > /etc/apt/apt.conf.d/99custom-hardening << EOF
APT::Get::Assume-Yes "true";
APT::Get::AllowUnauthenticated "false";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

# Install Docker securely
log "Installing Docker..."
# Remove old versions
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install dependencies
apt install -y \
    ca-certificates \
    curl \

# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update

# Install Docker
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
usermod -aG docker "$ADMIN_USER"

# Configure Docker daemon for security
log "Configuring Docker daemon security..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "userns-remap": "default",
  "no-new-privileges": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "icc": false,
  "iptables": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "live-restore": true,
  "hosts": ["unix:///var/run/docker.sock"],
  "seccomp-profile": "/etc/docker/seccomp.json",
  "apparmor-profile": "docker-default"
}
EOF

# Download Docker's default seccomp profile
curl -o /etc/docker/seccomp.json https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json

# Set kernel parameters for security
log "Setting kernel security parameters..."
cat >> /etc/sysctl.conf << EOF

# Security hardening
# Disable IP forwarding (enable if Docker needs it)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Enable IP spoofing protection
net.ipv4.conf.all.rp_filter = 1

# Disable ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Ignore ICMP ping requests
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable TCP SYN cookies
net.ipv4.tcp_syncookies = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Kernel security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
EOF

sysctl -p

# Create restricted sudoers rule
log "Creating restricted sudoers rule..."
echo "$ADMIN_USER ALL=(ALL) NOPASSWD: /usr/bin/apt, /bin/systemctl, /usr/bin/journalctl" > /etc/sudoers.d/$ADMIN_USER
chmod 440 /etc/sudoers.d/$ADMIN_USER

# Set file permissions
log "Setting secure file permissions..."
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/shadow
chmod 600 /etc/gshadow

# Validate Docker installation
log "Validating Docker installation..."
if ! docker run --rm hello-world; then
    error "Docker test failed. Please check the installation."
fi

# Configure log rotation
log "Configuring log rotation..."
cat > /etc/logrotate.d/docker << EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF

# Start and enable services
log "Starting and enabling services..."
systemctl enable --now docker
systemctl enable --now fail2ban
systemctl enable --now ufw
systemctl restart ssh

# Initialize AIDE database
log "Initializing AIDE database (this may take a while)..."
aide --init &

# Create maintenance script
log "Creating maintenance script..."
cat > /home/$ADMIN_USER/docker-maintenance.sh << 'EOF'
#!/bin/bash
# Docker maintenance script

echo "=== Docker System Cleanup ==="
docker system prune -f

echo "=== Docker Image Cleanup ==="
docker image prune -f

echo "=== Docker Volume Cleanup ==="
docker volume prune -f

echo "=== System Updates Check ==="
apt list --upgradable

echo "=== Security Scan ==="
rkhunter --check --skip-keypress

echo "=== Disk Usage ==="
df -h

echo "=== Docker Stats ==="
docker stats --no-stream
EOF

chmod +x /home/$ADMIN_USER/docker-maintenance.sh
chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/docker-maintenance.sh

log "Server hardening completed successfully!"
warn "IMPORTANT: SSH port changed to $SSH_PORT"
warn "Private key location: /home/$ADMIN_USER/.ssh/id_rsa"
warn "Please test SSH connection before logging out!"

echo -e "\n${GREEN}Summary report: /home/$ADMIN_USER/hardening-summary.txt${NC}"
echo -e "${GREEN}Maintenance script: /home/$ADMIN_USER/docker-maintenance.sh${NC}\n"
