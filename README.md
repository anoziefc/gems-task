# 🚀 Secure CI/CD Platform with Docker, Jenkins & Traefik

This project demonstrates a **secure CI/CD pipeline** powered by **Jenkins**, **Docker**, and **Traefik**, designed for deploying containerized applications behind HTTPS with production-ready practices.

It automates the process of:
- Pulling code from GitHub
- Building and pushing Docker images to Docker Hub
- Deploying applications behind Traefik with HTTPS via Let's Encrypt
- Secure credential management via Jenkins Credentials Manager
- Infrastructure and service hardening for production safety

---

## 📌 Key Features

✅ Jenkins installed via Docker behind Traefik (TLS-enabled)
✅ Automated Docker image build + push from GitHub to Docker Hub
✅ Secure deployment behind Traefik with Let's Encrypt SSL
✅ Dynamic routing via Docker labels
✅ Hardened setup with firewall, fail2ban, non-root users, and auto-updates
✅ Optional CI/CD trigger via SSH from Jenkins

---

## 🧱 Project Structure

```
├── deploy-app/
│   ├── deploy.sh                     # Deployment script for container with Traefik
│   ├── docker-compose.yml            # Application service behind Traefik
│   ├── README.md                     # Readme File
│   └── Jenkinsfile                   # CI pipeline logic
├── jenkins/
│   ├── Dockerfile                    # Jenkins setup with Docker CLI
│   ├── docker-compose.yml            # Jenkins service behind Traefik
│   ├── plugins.txt                   # Required Jenkins plugins
│   ├── init.groovy.d/
│   │   └── basic-security.groovy     # Basic security for jenkins
│   ├── README.md                     # Readme File
│   └── Jenkinsfile                   # CI pipeline logic
├── linux_hardening/
│   ├── hardening.sh                  # setup security on ubuntu vm
│   └── README.md                     # Readme File
├── traefik/
│   ├── docker-compose.yml            # Jenkins service behind Traefik
│   ├── setup.sh                      # Required Jenkins plugins
│   ├── traefik/
│   │   ├── dynamic.yml               # Required Jenkins plugins
│   │   └── traefik.yml               # Required Jenkins plugins
│   └── README.md                     # CI pipeline logic
└── README.md                         # This file
```

---

## 🧪 How to Reproduce (Step-by-Step)

### 1. **Prepare Server**

- OS: Ubuntu 22.04
- Provision a VM with root access
- Install dependencies eg docker-ci, docker, docker-compose, ufw, curl etc
- Create non-root user and .ssh directory
- Create ssh key for user, store pub key in .ssh/authorized_keys
- Restrict permissions to .ssh/authorized_keys giving only the own rw permissions
- Configure the SSH Daemon, change ssh port, disabling root login and password login
- Allow only the created user ssh access, enable only pubkey authentication
- Configure UFW firewall, deny all incoming connections, allow only outgoing
- Allow incoming connections to Port `80`, `443` and SSH `2222`
- Configure fail2ban
- Configure automatic security updates
- Setting kernel security parameters
- Create restricted sudoers rule to allow user only install packages and enable/start packages
- Test SSH connection before restarting VM

### 2. **Provision Traefik (if not already)**

- Create docker-compose with configuration for Traefik, Whoami and Nginx
- Route all connections to traefik network
- Route TLS Cert Challenge to Let's Encrypt
- Redirect all HTTP connections to HTTPS
- Test connections

### 3. **Set Up Jenkins (CI)**

- Create docker-compose with configuration for Jenkins
- Route Jenkins connections to go through already provisioned traefik network
- Route TLS Cert Challenge to Let's Encrypt
- Test connections
- Login with `admin` / `admin123`
- Install suggested plugins
- Add credentials:
  - **GitHub**: Username + Personal Access Token (PAT)
  - **Docker Hub**: Username + Personal Access Token (PAT)
  - **SSH**: Private key for deployment (label: `deploy-key`)
- Run CI Pipeline: The `Jenkinsfile` performs:
  - Git clone
  - Docker login
  - Image build + tag
  - Push to Docker Hub
  - Trigger deployment script over SSH

### 4. **Deploy Application**

```bash
cd deploy-app/
chmod +x deploy.sh
./deploy.sh production latest
```
Your app is now live at:  
👉 `https://app.example.com`

---
## 🔐 Credentials / Secrets Strategy (Mocked)

| Purpose           | Strategy                          | Storage                      |
|-------------------|-----------------------------------|------------------------------|
| GitHub Access     | Personal Access Token (PAT)       | Jenkins Credentials Manager  |
| Docker Hub Push   | Username/Password                 | Jenkins Credentials Manager  |
| SSH Deployment    | Private Key (readonly scope)      | Jenkins Credentials Manager  |
| Traefik Basic Auth| `.htpasswd`                       | Mounted file or env var      |
| TLS Certs         | Let's Encrypt (auto-managed)      | Persisted via Traefik volume |

All secrets are stored securely and **never hardcoded** in version-controlled files.

---

## 🛡️ Production Hardening Summary

- 🔐 SSH key-only login
- 🔒 Jenkins admin bootstrapped + credential manager used
- 🔥 UFW firewall + Fail2Ban configured
- 🚫 Rootless containers where applicable
- 🧼 Unattended upgrades enabled
- 🔁 Docker socket access restricted to Jenkins container
- 🌐 HTTPS enforced via Traefik

---

## 🧠 Improvements with More Time

1. **Pipeline Enhancements**
   - Add staging/production environment matrix
   - Add test/lint steps before build
   - Store artifacts + logs in S3 or MinIO

2. **Observability**
   - Integrate Prometheus + Grafana for monitoring
   - Alerting on failed builds or deployment health

3. **Vaulted Secrets**
   - Use HashiCorp Vault or SOPS to manage secrets instead of Jenkins credentials alone

4. **Container Security**
   - Add image scanning with Trivy or Clair
   - Enforce signed Docker images (Cosign)

5. **Zero Downtime Deployments**
   - Add support for blue-green or rolling updates using Traefik routing

---

## ✅ Final Note

This project is built as a secure foundation for CI/CD automation using open-source tools and follows DevOps best practices. The code is modular, production-viable, and extensible for more advanced use cases.