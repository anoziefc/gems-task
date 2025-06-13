# 🛡️ Linux Server Hardening for Docker Host

This setup provides a hardened Linux environment for securely hosting Docker containers. The configuration has been tested on **Ubuntu 22.04 LTS** (can be adapted to **CentOS 8** if needed).

---

## 🔧 Features & Hardening Measures

* **Non-root sudo user** created for administrative tasks.
* **SSH hardening**: root login disabled, only key-based authentication enabled, changed ssh port
* **Firewall configured**: Uncomplicated Firewall and fail2ban
* **Port Closing**: Closed all ports except 2222/tcp for ssh, 80/tcp for HTTP and 443/tcp for HTTPS
* **Configured Auto Security Updates**

* **Docker & Docker Compose installed securely** from official repositories.
* Basic best practices followed for **system security and package integrity**.

---

## 📜 Usage

### 1. Clone Repository

```bash
git clone https://github.com/anoziefc/gems-task.git/
cd gems-task/linux_hardening
```

### 2. Run Setup

```bash
chmod +x hardening.sh
./hardening.sh
```
---

## 🔐 Security Notes
* ✓ Created non-root sudo user: dockeradmin
* ✓ Disabled root SSH login
* ✓ Changed SSH port to: 2222
* ✓ Configured key-based SSH authentication
* ✓ Enabled UFW firewall
* ✓ Configured fail2ban
* ✓ Installed Docker with security settings
* ✓ Configured automatic security updates
* ✓ Applied kernel security parameters
* ✓ Set up log rotation
* ✓ Initialized AIDE intrusion detection

---

## 📁 Files Included

* `hardening.sh` – Bash script to harden and configure the server
* `README.md` – This file

---

## ✅ Post-Setup Checklist

* [*] Copy SSH private key to your local machine
* [*] Test SSH connection: ssh -p $SSH_PORT $ADMIN_USER@$(hostname -I | awk '{print $1}')
* [*] Verify root SSH login is disabled
* [*] Check Docker is installed and the daemon is running
* [*] Run maintenance script: /home/$ADMIN_USER/docker-maintenance.sh
* [*] Review firewall rules: ufw status
* [*] Check fail2ban status: fail2ban-client status

## ✅ Regular Maintenance
* [*] Run security updates: apt update && apt upgrade
* [*] Check AIDE: aide --check
* [*] Review logs: journalctl -xe
* [*] Monitor Docker: docker system df

---
