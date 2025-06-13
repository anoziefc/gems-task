# 🚀 Traefik Reverse Proxy Setup

This setup deploys **Traefik** as a reverse proxy using Docker Compose. It includes routing for two dummy services (e.g., `whoami`, `nginx-auth`), one protected by **HTTP Basic Auth**, and full **HTTPS support** via **Let’s Encrypt** (production environment). The **Traefik dashboard** is also enabled and secured.

---

## 📦 Services

* **Traefik** – Reverse proxy with Let's Encrypt & dashboard
* **Whoami** – Dummy web service (public)
* **Nginx-auth** – Dummy web service (protected with Basic Auth)

---

## 📁 Directory Structure

```
traefik/
├── docker-compose.yml
├── setup.sh
└── traefik/
    ├── traefik.yml      # Static configuration
    └── dynamic.yml      # Dynamic configuration

```

---

## 🔧 How to Use

### 1. Clone Repository

```bash
git clone https://github.com/anoziefc/gems-task.git
cd gems-task/traefik
```

### 2. Configure Your Domain

Update `docker-compose.yml` with your own domain. for testing use duckdns.org to generate dns


### 3. Set Password for authentication, update password in setup.sh

Update line 25 in setup.sh with your own password and username.
`htpasswd -nbB admin admin123 > traefik/users.txt`


### 4. Launch the Stack
Run bash script and start up docker
```bash
chmod +x setup.sh
docker compose up -d
```

---

## 🔐 Security Features

* **Basic Auth**: protected using bcrypt credentials from `users.txt`.
* **HTTPS via Let's Encrypt**:
  * production server is used for including no rate limits.
  * Automatically issues certificates for defined domains.
* **Secure Dashboard**:
  * Only accessible via `https://gemstraefic.duckdns.org/`
  * Protected with HTTP Basic Auth.
* **Secure Nginx-Auth**:
  * Only accessible via `https://gemsnginx.duckdns.org/`
  * Protected with the same HTTP Basic Auth.
* **Unsecure Whoami**:
  * Accessible via `https://mywhoami.duckdns.org/`
---

## 🛠 Configuration Overview

### 🔹 docker-compose.yml

* Declares all services and routing labels
* Mounts config volumes for Traefik
* Exposes ports 80/443 for HTTP/HTTPS
* All requests to 80 are redirected to 443

### 🔹 traefik/traefik.yml (Static Config)

```yaml
global:
  checkNewVersion: false
  sendAnonymousUsage: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik
  file:
    filename: /dynamic.yml
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@domain.com
      storage: acme.json
      caServer: https://acme-v02.api.letsencrypt.org/directory
      httpChallenge:
        entryPoint: web

api:
  dashboard: true
  debug: false

log:
  level: INFO
  filePath: "/var/log/traefik.log"

accessLog:
  filePath: "/var/log/access.log"
```

### 🔹 traefik/dynamic.yml (Dynamic Config)

```yaml
http:
  middlewares:
    dashboard-auth:
      basicAuth:
        usersFile: "/users.txt"
    nginx-basic-auth:
      basicAuth:
        usersFile: "/users.txt"

tls:
  options:
    default:
      minVersion: "VersionTLS12"

```

### 🔹 traefik/usersfile.txt

```txt
admin:$2y$12$...  # Generated with htpasswd -nbB admin yourpassword
```

---

## 🌐 Access URLs

| Service        | URL                                              | Notes               |
| -------------- | ------------------------------------------------ | ------------------- |
| Public Whoami  | [http://whomai.duckdns.org]                      | Open                |
| Secured Nginx  | [https://nginx-auth.duckdns.org]                 | Requires Basic Auth |
| Dashboard      | [https://traefik-admin-dashboard.duckdns.org]    | Requires Basic Auth |

---

## 🧪 Testing

* Make sure DNS is correctly configured via duckdns.org
* Access each service via browser
* Confirm TLS is active (HTTPS padlock)
* Confirm basic auth prompts on `Secured Nginx` and `Dashboard`

---

## 🧼 Cleanup

To stop and remove all containers:

```bash
docker compose down -v
```

---

## 📬 Notes

* Use **secure permissions** on `acme.json` and `users.txt`.
  ```bash
  chmod 600 traefik/acme.json traefik/users.txt
  ```
* Change default passwords before production
* Use **strong** and **unique passwords**
* Consider IP whitelisting for sensitive services
* Monitor access logs regularly
* Keep Traefik updated to latest version
* Use DNS challenge for better security when possible
---

