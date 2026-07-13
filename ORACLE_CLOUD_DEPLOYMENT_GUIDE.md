# Secure Production Deployment Guide
## SpeakIt Backend on Oracle Cloud Free Tier

**Target:** Ubuntu LTS on Oracle Cloud with ARM Ampere instance
**Stack:** Spring Boot 3.5.11, Java 21, PostgreSQL/Supabase, JWT Auth
**Security Level:** Production-grade hardening, SSH-only management

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Oracle Cloud Infrastructure Setup](#oracle-cloud-infrastructure-setup)
3. [Server Hardening (SSH-Only)](#server-hardening-ssh-only)
4. [Firewall Configuration](#firewall--port-security)
5. [Environment File & Secret Protection](#env-file--secret-protection)
6. [Application Deployment](#spring-boot-deployment)
7. [NGINX & HTTPS Setup](#nginx--https-security)
8. [Monitoring & Safety](#monitoring--server-safety)
9. [Deployment Checklists](#deployment-checklists)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           INTERNET                                       │
│                                                                         │
│    ┌──────────────────────────────────────────────────────────────┐    │
│    │                     OCI CLOUD                                 │    │
│    │                                                            │    │
│    │  ┌─────────────────────────────────────────────────────────┐│    │
│    │  │              VCN (Virtual Cloud Network)               ││    │
│    │  │                                                         ││    │
│    │  │  ┌─────────────────┐    ┌────────────────────────┐    ││    │
│    │  │  │   STATIC PUBLIC  │    │    INSTANCE (ARM)      │    ││    │
│    │  │  │   IP (Reserved) │◄──►│                         │    ││    │
│    │  │  └─────────────────┘    │  ┌──────────────────┐  │    ││    │
│    │  │                        │  │  UFW Firewall     │  │    ││    │
│    │  │  ┌─────────────────┐   │  │  ├─ 22  (SSH)     │  │    ││    │
│    │  │  │  Internet       │   │  │  ├─ 80  (HTTP)    │  │    ││    │
│    │  │  │  Gateway        │   │  │  └─ 443 (HTTPS)   │  │    ││    │
│    │  │  └────────┬────────┘   │  └──────────────────┘  │    ││    │
│    │  │           │            │                         │    ││    │
│    │  │  ┌────────▼────────┐   │  ┌──────────────────┐  │    ││    │
│    │  │  │  Route Table   │   │  │  Security List   │  │    ││    │
│    │  │  │  + NSG Rules   │   │  │  (Stateful)      │  │    ││    │
│    │  │  └────────────────┘   │  └──────────────────┘  │    ││    │
│    │  │                        │                         │    ││    │
│    │  │  ┌─────────────────────▼──────────────────────────┐│    │    │
│    │  │  │           PUBLIC SUBNET                          ││    │    │
│    │  │  │  ┌─────────────────────────────────────────┐    ││    │    │
│    │  │  │  │           SPRING BOOT APP               │    │    ││    │
│    │  │  │  │  ┌─────────┐ ┌─────────┐ ┌───────────┐  │    ││    │    │
│    │  │  │  │  │ NGINX   │ │ App:8080│ │ Certbot   │  │    ││    │    │
│    │  │  │  │  │ (443)  │ │(internal)│ │(Auto-renew)│  │    ││    │    │
│    │  │  │  │  └────┬────┘ └────┬────┘ └───────────┘  │    ││    │    │
│    │  │  │  └───────┼───────────┼─────────────────────┘    ││    │    │
│    │  │  └──────────┼───────────┼────────────────────────────┘    │    │
│    │  └─────────────┼───────────┼──────────────────────────────────┘    │
│    │                │           │                                          │
│    └────────────────┼───────────┼──────────────────────────────────────────┘
│                     │           │
│                     ▼           ▼
│              ┌────────────┐  ┌────────────┐
│              │ Supabase   │  │ AWS Polly   │
│              │ PostgreSQL │  │ (TTS API)  │
│              └────────────┘  └────────────┘
└─────────────────────────────────────────────────────────────────────────┘
```

### Security Layers (Defense in Depth)

```
Layer 1: OCI Security List    → Filter traffic BEFORE it reaches instance
Layer 2: OCI NSG             → Additional network-level filtering
Layer 3: UFW (Ubuntu FW)     → OS-level firewall rules
Layer 4: NGINX               → Reverse proxy with request filtering
Layer 5: Application         → Spring Boot internal binding (127.0.0.1)
```

---

## Oracle Cloud Infrastructure Setup

### Step 1: Initial OCI Account Configuration

**Why this matters:** Oracle Cloud Free Tier provides:
- Always Free ARM instance (1GB RAM, 50GB storage)
- 2VLMs (Volatile Local Machine) included
- Object Storage (10GB)
- Unlimited Free Tier usage for eligible resources

**Steps to create OCI account:**
1. Visit https://www.oracle.com/cloud/free/ and sign up
2. Verify email and add payment method (won't be charged on Free Tier)
3. Choose your home region (select closest to your users)
4. Accept terms and create account

### Step 2: Create a Compartment

**Why compartments matter:** Logical isolation for billing, access control, and resource management.

**OCI Console → Identity → Compartments → Create Compartment**

```yaml
Name: speakit-prod
Description: Production resources for SpeakIt backend
Parent Compartment: Root (tenancy)
```

### Step 3: Create VCN (Virtual Cloud Network)

**Why VCN matters:** Isolated network space. All your cloud resources communicate within this network.

**OCI Console → Networking → Virtual Cloud Networks → Create VCN**

```yaml
Name: speakit-vcn
CIDR Block: 10.0.0.0/16          # Private network space
DNS Label: speakitvcn             # For Oracle DNS services
```

### Step 4: Configure Internet Gateway

**Why Internet Gateway:** Allows resources in VCN to reach the internet (outbound) AND receive inbound connections.

**OCI Console → Networking → Internet Gateways → Create Internet Gateway**

```yaml
Name: speakit-igw
Compartment: speakit-prod
Enabled: true
```

### Step 5: Create Route Table

**Why Route Tables:** Direct traffic between subnets and gateways.

**OCI Console → Networking → Route Tables → Create Route Table**

```yaml
Name: speakit-rt
Routes:
  - Destination: 0.0.0.0/0 (All Internet Traffic)
    Target: speakit-igw (Internet Gateway)
```

### Step 6: Create Subnet

**OCI Console → Networking → Subnets → Create Subnet**

```yaml
Name: speakit-public-subnet
CIDR Block: 10.0.0.0/24
Route Table: speakit-rt
Subnet Access: Public (assign public IP)
DNS in Subnet: Enabled
```

### Step 7: Security List Configuration

**Why Security Lists:** Stateful firewall at cloud level. Oracle evaluates rules top-to-bottom.

**OCI Console → Networking → Security Lists → Default Security List (or create new)**

**Ingress Rules (Inbound Traffic):**

| Priority | Source CIDR | Protocol | Ports | Purpose |
|----------|-------------|----------|-------|---------|
| 100 | 0.0.0.0/0 | TCP | 443 | HTTPS from anywhere |
| 110 | 0.0.0.0/0 | TCP | 80 | HTTP (for Let's Encrypt) |
| 120 | YOUR_IP/32 | TCP | 22 | SSH from YOUR specific IP |

**⚠️ SECURITY BEST PRACTICE:** Replace `0.0.0.0/0` for SSH with your specific IP address. This prevents SSH brute force from the entire internet.

**Egress Rules (Outbound Traffic):**
- Leave defaults (allow all) OR restrict to specific destinations (Supabase, AWS)

### Step 8: Reserve Static Public IP

**Why Static IP:** Required for DNS records and consistent access point. Changes on instance restart without reservation.

**OCI Console → Networking → Reserved IP Addresses → Reserve IP Address**

```yaml
Name: speakit-backend-ip
Compartment: speakit-prod
```

**Save this IP address** — you'll need it for:
- DNS A record configuration
- SSH access
- Monitoring

### Step 9: Launch Instance

**OCI Console → Compute → Instances → Create Instance**

```yaml
Name: speakit-backend

# Placement
Compartment: speakit-prod
Availability Domain: AD-1 (or any available)

# Image and Shape
Image: Ubuntu 24.04 LTS (ARM64)  # Always Free eligible
Shape: VM.Standard.A1.Flex        # ARM Ampere, Always Free
OCPUs: 1
Memory: 6GB                      # Free Tier max for ARM

# Networking
Network: speakit-vcn
Subnet: speakit-public-subnet
Assign Public IP: Enabled
```

**⚠️ IMPORTANT:** Under "Add SSH keys", choose:
- **Option A (Recommended):** "Generate SSH key pair" — Oracle generates private key
- **Option B:** Upload your own `~/.ssh/id_rsa.pub`

**Download and SAVE the private key securely — you cannot retrieve it later!**

---

## Server Hardening (SSH-Only)

### Initial Server Setup

SSH to your instance using the saved private key:

```bash
ssh -i /path/to/your/private_key opc@<YOUR_PUBLIC_IP>
```

**Why `opc` user:** Oracle Cloud instances use `opc` (Oracle Cloud Platform) as the default sudo user. It's pre-configured with sudo access.

### Step 1: Update System Packages

```bash
# Update package lists and upgrade all packages
sudo apt update && sudo apt upgrade -y

# Install essential security packages
sudo apt install -y unattended-upgrades apt-listchanges
```

### Step 2: Create Deployment User

**Why non-root deployment:** Principle of least privilege. Application should never run as root.

```bash
# Create deployment user with sudo access
sudo adduser deploy

# Add to sudo group for admin tasks
sudo usermod -aG sudo deploy

# Add to adm group for log reading
sudo usermod -aG adm deploy
```

### Step 3: Configure SSH for Deploy User

```bash
# Create .ssh directory
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh

# Authorize your SSH key
sudo cp /home/opc/.ssh/authorized_keys /home/deploy/.ssh/
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
```

### Step 4: SSH Daemon Hardening

**Edit SSH config:**

```bash
sudo nano /etc/ssh/sshd_config
```

**Hardened configuration:**

```ssh-config
# SSH Protocol Version
Protocol 2

# Disable root login
PermitRootLogin no

# Disable password authentication
PasswordAuthentication no
PermitEmptyPasswords no

# Disable SSH tunneling and forwarding if not needed
AllowTcpForwarding no
X11Forwarding no
AllowAgentForwarding no

# Restrict to specific users
AllowUsers deploy

# Limit connection attempts
MaxAuthTries 3
MaxSessions 2

# Client alive settings (auto-disconnect idle sessions)
ClientAliveInterval 300        # Check every 5 minutes
ClientAliveCountMax 2         # Disconnect after 2 missed checks (10 min total)

# Disable weak key exchange algorithms
KexAlgorithms curve25519-sha256

# Disable weak ciphers (only strong ones)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

# Disable weak MAC algorithms
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Banner message (optional legal warning)
Banner /etc/ssh/banner

# Disable connection multiplexing
ControlMaster no
ControlPath none
ControlPersist 0

# Use privilege separation
UsePrivilegeSeparation sandbox
```

**Create SSH banner (legal warning):**

```bash
sudo nano /etc/ssh/banner
```

```text
************************************************************
     AUTHORIZED ACCESS ONLY
     This system is for authorized use only.
     Individuals using this computer system without
     authority or in excess of their authority are subject
     to having all their activities monitored and recorded.
************************************************************
```

```bash
sudo chmod 644 /etc/ssh/banner
```

### Step 5: Restart SSH Service

```bash
# Verify configuration syntax
sudo sshd -t

# Restart SSH service
sudo systemctl restart sshd
```

**⚠️ CRITICAL: Test SSH connection BEFORE logging out!**

In a NEW terminal:

```bash
ssh -i /path/to/private_key deploy@<YOUR_PUBLIC_IP>
```

If successful, return to original session and continue.

### Step 6: Configure Fail2Ban

**Why Fail2Ban:** Automatically blocks IPs with repeated failed login attempts. Essential for SSH brute-force protection.

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create local configuration (don't edit default)
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
# Ban time: 24 hours after 10 failed attempts
bantime = 86400
findtime = 3600
maxretry = 10

[sshd]
enabled = true
port = 22
action = iptables-multiport
logpath = /var/log/auth.log
```

```bash
# Enable and start fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Verify it's running
sudo fail2ban-client status
```

### Step 7: Enable Automatic Security Updates

```bash
# Configure automatic updates
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

```apt-config
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::AutomaticReboot "false";
```

```bash
# Enable automatic updates
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```

```apt-config
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
```

### Step 8: Install Additional Security Tools

```bash
# Install essential security packages
sudo apt install -y \
    auditd \           # Linux audit framework
    rkhunter \        # Rootkit hunter
    libpam-runtime    # PAM modules

# Configure audit rules
sudo nano /etc/audit/rules.d/audit.rules
```

```audit-rules
# Monitor SSH access
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /var/log/auth.log -p wa -k auth_log

# Monitor sensitive files
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k owner_change
```

```bash
# Enable audit daemon
sudo systemctl enable auditd
sudo systemctl start auditd
```

### Step 9: Secure File Permissions Globally

```bash
# Set secure umask (files created get 640, directories 750)
sudo nano /etc/login.defs
# Add or modify: UMASK 077

# Secure /tmp directory
sudo nano /etc/systemd/system/tmp.mount
```

```ini
[Mount]
What=tmpfs
Where=/tmp
Type=tmpfs
Options=mode=1777,strictatime,noexec,nodev,nosuid

[Unit]
Description=Temporary /tmp directory
ConditionPathIsSymbolicLink=/tmp
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable tmp.mount
```

### Step 10: Remove Unnecessary Services

```bash
# List active services
systemctl list-units --type=service --state=running

# Stop unnecessary services (examples - check your system)
sudo systemctl stop snapd 2>/dev/null || true
sudo systemctl disable snapd 2>/dev/null || true

# Check listening ports
sudo ss -tlnp
```

---

## Firewall & Port Security

### OCI Cloud Firewall Rules

**Configure in OCI Console → Networking → Security Lists:**

| Direction | Source | Protocol | Port(s) | Purpose |
|-----------|--------|----------|---------|---------|
| INGRESS | 0.0.0.0/0 | TCP | 443 | HTTPS from internet |
| INGRESS | 0.0.0.0/0 | TCP | 80 | HTTP (Let's Encrypt) |
| INGRESS | YOUR_IP/32 | TCP | 22 | SSH from YOUR IP only |
| EGRESS | 0.0.0.0/0 | TCP | 443 | HTTPS outbound |
| EGRESS | 0.0.0.0/0 | TCP | 80 | HTTP outbound |

**⚠️ WHY ONLY THESE PORTS:**
- **443 (HTTPS):** Encrypted web traffic to your API
- **80 (HTTP):** Required for Let's Encrypt certificate issuance/renewal
- **22 (SSH):** Your access point for server management

### UFW (Ubuntu Firewall) Configuration

**Why UFW:** Additional defense layer at OS level. Even if cloud rules fail, OS firewall provides protection.

```bash
# Install and enable UFW
sudo apt install -y ufw

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed   # Not a router

# Allow SSH (limit rate to prevent brute force)
sudo ufw limit 22/tcp comment 'SSH with rate limiting'

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp comment 'HTTP for Let\'s Encrypt'
sudo ufw allow 443/tcp comment 'HTTPS secure web'

# Enable UFW
sudo ufw enable

# Verify rules
sudo ufw status verbose

# Check UFW logs
sudo ufw status numbered
```

**Expected output:**
```
To                         Action      From
--                         ------      ----
22/tcp                     Limit       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

### Network Namespace Isolation (Optional Advanced)

For additional isolation, consider running the app in a network namespace that only has outbound access.

---

## Env File & Secret Protection

### Step 1: Create Secure Directory Structure

```bash
# Create application directory with restricted permissions
sudo mkdir -p /opt/speakit/backend
sudo mkdir -p /opt/speakit/backend/logs
sudo mkdir -p /opt/speakit/backend/tmp

# Create hidden config directory
sudo mkdir -p /opt/speakit/config

# Set ownership to deploy user
sudo chown -R deploy:deploy /opt/speakit
sudo chmod -R 700 /opt/speakit

# Set strict permissions
sudo chmod 750 /opt/speakit/backend
sudo chmod 700 /opt/speakit/config
sudo chmod 750 /opt/speakit/backend/logs
sudo chmod 700 /opt/speakit/backend/tmp
```

### Step 2: Create Environment File

```bash
sudo nano /opt/speakit/config/.env.backend
```

```env
# AWS Polly Configuration
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_REGION=us-east-1

# Supabase PostgreSQL
SPRING_DATASOURCE_URL=jdbc:postgresql://db.xxx.supabase.co:5432/postgres
SPRING_DATASOURCE_USERNAME=postgres
SPRING_DATASOURCE_PASSWORD=your_db_password

# JWT Security
JWT_SECRET=your_very_long_and_secure_jwt_secret_min_256_bits
JWT_EXPIRATION_MS=86400000

# CORS Configuration
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# Rate Limiting
RATE_LIMIT_CAPACITY=100
RATE_LIMIT_REFILL_TOKENS=100
RATE_LIMIT_REFILL_DURATION_MINUTES=1

# Server Configuration
SERVER_PORT=8080
```

```bash
# Set strict permissions (owner read/write only)
sudo chmod 600 /opt/speakit/config/.env.backend
sudo chown deploy:deploy /opt/speakit/config/.env.backend
```

**⚠️ CRITICAL SECURITY NOTES:**
1. **Never commit `.env` files to git** — Add to `.gitignore`
2. **The leading dot (`.env.backend`)** makes it hidden
3. **600 permissions** means only root and deploy can read
4. **Only deploy user** should have access

### Step 3: Git Protection

```bash
# Add to .gitignore in your project
echo ".env" >> /home/cyberbully/Documents/Desktop/git-projects/speakit/.gitignore
echo ".env.*" >> /home/cyberbully/Documents/Desktop/git-projects/speakit/.gitignore
echo "*.env" >> /home/cyberbully/Documents/Desktop/git-projects/speakit/.gitignore
```

### Step 4: Secure Environment Loading for Spring Boot

Spring Boot natively supports environment files. The systemd service will handle this.

```bash
# Verify env file is loaded by checking
cat /opt/speakit/config/.env.backend
# Should show content with correct permissions
```

---

## Spring Boot Deployment

### Step 1: Build the Application Locally

**On your local machine:**

```bash
cd /home/cyberbully/Documents/Desktop/git-projects/speakit/backend

# Clean and build
./mvnw clean package -DskipTests

# The JAR file will be at:
# target/TextToSpeechApplication-0.0.1-SNAPSHOT.jar
```

**Transfer to server (from your local machine):**

```bash
scp -i /path/to/private_key \
    target/TextToSpeechApplication-0.0.1-SNAPSHOT.jar \
    deploy@<YOUR_PUBLIC_IP>:/opt/speakit/backend/
```

### Step 2: Create Systemd Service

```bash
sudo nano /etc/systemd/system/speakit-backend.service
```

```ini
[Unit]
Description=SpeakIt Spring Boot Backend
Documentation=https://github.com/mohitur/speakit
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=deploy
Group=deploy

# Environment file location
EnvironmentFile=/opt/speakit/config/.env.backend

# Working directory
WorkingDirectory=/opt/speakit/backend

# Java options
# -Xms: Initial heap size
# -Xmx: Maximum heap size (512MB is good for 1GB RAM)
# -XX:+UseG1GC: G1 garbage collector (good for low memory)
# -Dserver.port=127.0.0.1: Bind to localhost only (CRITICAL for security)
ExecStart=/usr/bin/java \
    -Xms256m \
    -Xmx512m \
    -XX:+UseG1GC \
    -XX:+ExitOnOutOfMemoryError \
    -Dspring.profiles.active=prod \
    -Dserver.address=127.0.0.1 \
    -Dserver.port=8080 \
    -Djava.security.egd=file:/dev/./urandom \
    -jar /opt/speakit/backend/TextToSpeechApplication-0.0.1-SNAPSHOT.jar

# Restart policy
Restart=on-failure
RestartSec=10
StartLimitBurst=3
StartLimitIntervalSec=60

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=speakit-backend

# Hardening: Prevent execution from /tmp
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectClock=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectHostname=true
ProtectEnvironment=true

# Capability restrictions
CapabilityBoundingSet=
AmbientCapabilities=

[Install]
WantedBy=multi-user.target
```

```bash
# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable speakit-backend

# Verify service is properly configured
sudo systemctl cat speakit-backend
```

### Step 3: Configure JVM for Production

Create JVM options file for additional tuning:

```bash
sudo nano /etc/systemd/system/speakit-backend.service.d/jvm-tuning.conf
```

```ini
[Service]
# Additional JVM flags for production
Environment="JAVA_TOOL_OPTIONS=-Djava.rmi.server.hostname=127.0.0.1"
```

```bash
sudo systemctl daemon-reload
```

### Step 4: Start and Verify Service

```bash
# Start the service
sudo systemctl start speakit-backend

# Check status
sudo systemctl status speakit-backend

# View logs
sudo journalctl -u speakit-backend -f

# Check if listening on correct port
sudo ss -tlnp | grep 8080

# Test health endpoint
curl -I http://127.0.0.1:8080/api/tts/voices
```

**Expected response:** `200 OK` or proper JSON response

### Step 5: Create Deployment Script

```bash
sudo nano /opt/speakit/deploy.sh
```

```bash
#!/bin/bash
#
# SpeakIt Backend Deployment Script
# Usage: sudo /opt/speakit/deploy.sh <jar-file-path>
#

set -e

JAR_FILE="$1"
APP_DIR="/opt/speakit/backend"
CONFIG_DIR="/opt/speakit/config"
BACKUP_DIR="/opt/speakit/backup"
SERVICE_NAME="speakit-backend"

if [ -z "$JAR_FILE" ]; then
    echo "Usage: $0 <path-to-jar-file>"
    exit 1
fi

if [ ! -f "$JAR_FILE" ]; then
    echo "Error: JAR file not found: $JAR_FILE"
    exit 1
fi

echo "=== SpeakIt Backend Deployment ==="
echo "New JAR: $JAR_FILE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stop service gracefully
echo "Stopping $SERVICE_NAME..."
sudo systemctl stop "$SERVICE_NAME"

# Backup current JAR
if [ -f "$APP_DIR/TextToSpeechApplication-0.0.1-SNAPSHOT.jar" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp "$APP_DIR/TextToSpeechApplication-0.0.1-SNAPSHOT.jar" \
       "$BACKUP_DIR/TextToSpeechApplication-$TIMESTAMP.jar"
    echo "Backed up current JAR to $BACKUP_DIR"
fi

# Copy new JAR
cp "$JAR_FILE" "$APP_DIR/TextToSpeechApplication-0.0.1-SNAPSHOT.jar"
chown deploy:deploy "$APP_DIR/TextToSpeechApplication-0.0.1-SNAPSHOT.jar"

# Start service
echo "Starting $SERVICE_NAME..."
sudo systemctl start "$SERVICE_NAME"

# Wait for startup
sleep 10

# Check status
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "=== Deployment successful ==="
    sudo systemctl status "$SERVICE_NAME" --no-pager
else
    echo "=== Deployment FAILED ==="
    echo "Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
```

```bash
sudo chmod 750 /opt/speakit/deploy.sh
sudo chown root:deploy /opt/speakit/deploy.sh
```

---

## NGINX & HTTPS Security

### Step 1: Install NGINX and Certbot

```bash
# Install NGINX and Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# Ensure NGINX is stopped (we'll configure first)
sudo systemctl stop nginx
```

### Step 2: Configure NGINX Reverse Proxy

```bash
sudo nano /etc/nginx/sites-available/speakit-backend
```

```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;  # REPLACE with your domain

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self';" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    # Client request limits
    client_body_size 10M;
    client_max_body_size 10M;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;

    # Timeouts (prevent slow-loris)
    client_body_timeout 15s;
    client_header_timeout 15s;
    send_timeout 60s;

    # GZIP compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    # Rate limiting
    limit_req zone=api_limit burst=20 nodelay;
    limit_conn conn_limit 10;

    # Proxy settings
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;

    # Disable proxy buffering for streaming endpoints
    proxy_buffering off;
    proxy_buffer_size 4k;
    proxy_busy_buffers_size 8k;

    # Proxy timeouts
    proxy_connect_timeout 30s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:8080/api/tts/voices;
        proxy_set_header Host $host;
    }

    # API proxy to Spring Boot
    location / {
        proxy_pass http://127.0.0.1:8080;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

**⚠️ IMPORTANT:** Replace `yourdomain.com` with your actual domain name.

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/speakit-backend /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# If syntax OK, start NGINX
sudo systemctl enable nginx
sudo systemctl start nginx
```

### Step 3: Obtain SSL Certificate (Let's Encrypt)

```bash
# Stop NGINX briefly for certbot
sudo systemctl stop nginx

# Obtain certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com \
    --non-interactive \
    --agree-tos \
    --email your-email@example.com \
    --redirect \
    --hsts

# If you don't have DNS set up yet, use standalone mode:
# sudo certbot certonly --standalone -d yourdomain.com
```

**⚠️ DNS REQUIREMENT:** You must have an A record pointing to your server's IP before obtaining Let's Encrypt certificates.

### Step 4: Verify SSL Configuration

```bash
# Test SSL
sudo certbot renew --dry-run

# Check SSL grade
# Visit: https://www.ssllabs.com/ssltest/
# Or from server:
echo | openssl s_client -connect yourdomain.com:443 -starttls http 2>/dev/null | openssl x509 -noout -dates -subject
```

### Step 5: Configure Auto-Renewal

```bash
# Certbot auto-renewal should be enabled by default, but verify:
sudo systemctl status certbot.timer

# Test renewal manually
sudo certbot renew --dry-run

# View renewal logs
sudo journalctl -u certbot -n 50 --no-pager
```

### Step 6: Enhanced Security (Additional NGINX Hardening)

```bash
sudo nano /etc/nginx/nginx.conf
```

In the `http` block, add:

```nginx
http {
    # Security settings
    server_tokens off;                    # Hide nginx version
    charset utf-8;

    # Hide server tokens
    server_header off;

    # Request size limits
    client_max_body_size 10M;

    # Timeouts
    client_body_timeout 15s;
    client_header_timeout 15s;

    # Logging
    log_format security '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" '
                       '$request_time';

    access_log /var/log/nginx/access.log security;
    error_log /var/log/nginx/error.log warn;
}
```

---

## Monitoring & Server Safety

### Step 1: Set Up Log Rotation

```bash
sudo nano /etc/logrotate.d/speakit
```

```logrotate
/opt/speakit/backend/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 deploy deploy
    sharedscripts
    postrotate
        systemctl reload speakit-backend > /dev/null 2>&1 || true
    endscript
}
```

### Step 2: Create Monitoring Script

```bash
sudo nano /opt/speakit/monitor.sh
```

```bash
#!/bin/bash
#
# SpeakIt Server Monitoring Script
# Add to crontab: * * * * * /opt/speakit/monitor.sh
#

LOG_FILE="/opt/speakit/monitor.log"
ALERT_EMAIL="your-email@example.com"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check service health
if ! systemctl is-active --quiet speakit-backend; then
    log "ALERT: SpeakIt service is DOWN"
    systemctl restart speakit-backend
    log "Service restarted"
fi

# Check disk space (alert if > 90%)
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    log "ALERT: Disk usage at ${DISK_USAGE}%"
fi

# Check RAM usage (alert if > 90%)
RAM_USAGE=$(free | grep Mem | awk '{printf("%.0f"), $3/$2 * 100}')
if [ "$RAM_USAGE" -gt 90 ]; then
    log "ALERT: RAM usage at ${RAM_USAGE}%"
fi

# Check failed SSH logins
FAILED_LOGINS=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0)
log "Health check complete - Failed logins since boot: $FAILED_LOGINS"
```

```bash
sudo chmod 750 /opt/speakit/monitor.sh
sudo chown root:root /opt/speakit/monitor.sh
```

### Step 3: Configure Cron Jobs

```bash
sudo crontab -e
```

```cron
# Server monitoring every minute
* * * * * /opt/speakit/monitor.sh

# Clean old backups daily
0 3 * * * find /opt/speakit/backup -name "*.jar" -mtime +7 -delete

# Rotate monitor log weekly
0 0 * * 0 truncate -s 0 /opt/speakit/monitor.log
```

### Step 4: Create Health Check Endpoint

Your backend already has `/api/tts/voices`. Create a dedicated health endpoint:

```bash
# Test health endpoint
curl -f http://127.0.0.1:8080/api/tts/voices && echo "OK" || echo "FAIL"
```

### Step 5: Backup Recommendations

**Critical files to backup:**

```bash
# Create backup script
sudo nano /opt/speakit/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/opt/speakit/backup"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup config (encrypted in production)
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" /opt/speakit/config/

# Backup systemd service file
cp /etc/systemd/system/speakit-backend.service "$BACKUP_DIR/"

# Backup NGINX config
cp /etc/nginx/sites-available/speakit-backend "$BACKUP_DIR/"

echo "Backup created: $BACKUP_DIR"
```

---

## Deployment Checklists

### Pre-Deployment Checklist

- [ ] Oracle Cloud account created and verified
- [ ] Compartment created
- [ ] VCN with Internet Gateway configured
- [ ] Security List rules applied (22, 80, 443 only)
- [ ] Static IP reserved
- [ ] Ubuntu instance deployed with SSH keys
- [ ] SSH key downloaded and secured
- [ ] DNS A record configured for domain

### Server Hardening Checklist

- [ ] System updated (`apt update && apt upgrade`)
- [ ] `deploy` user created with sudo access
- [ ] SSH key authentication working for deploy user
- [ ] Password authentication disabled in sshd_config
- [ ] Root login disabled
- [ ] Fail2ban installed and configured
- [ ] UFW enabled with minimal rules
- [ ] Automatic security updates configured
- [ ] File permissions hardened
- [ ] Unnecessary services removed

### Application Deployment Checklist

- [ ] JAR file built with `mvn clean package -DskipTests`
- [ ] JAR file transferred to server via SCP
- [ ] Application directory created (`/opt/speakit`)
- [ ] Systemd service created and enabled
- [ ] Service started and verified
- [ ] Health endpoint responds correctly

### NGINX/HTTPS Checklist

- [ ] NGINX installed
- [ ] Reverse proxy configured
- [ ] Security headers added
- [ ] Rate limiting configured
- [ ] SSL certificate obtained via Let's Encrypt
- [ ] Auto-renewal verified
- [ ] HTTP → HTTPS redirect working

### Security Checklist

- [ ] SSH only on custom port (or IP-restricted)
- [ ] SSH key authentication only
- [ ] Fail2ban active and blocking
- [ ] UFW with default deny policy
- [ ] Backend not publicly accessible (127.0.0.1 binding)
- [ ] Environment file with correct permissions (600)
- [ ] No secrets in git history
- [ ] Systemd service with restricted capabilities

### Monitoring Checklist

- [ ] Log rotation configured
- [ ] Monitoring script created
- [ ] Cron jobs set up
- [ ] Service health check working
- [ ] Backup procedure documented

---

## Troubleshooting Guide

### SSH Connection Issues

**Problem:** Cannot connect via SSH

```bash
# From OCI Console → Instance → Actions → Instance Console
# Check if SSH service is running:
systemctl status sshd

# Check SSH config:
sshd -t

# View SSH logs:
tail -50 /var/log/auth.log
```

### Service Won't Start

```bash
# Check detailed logs:
journalctl -u speakit-backend -n 100 --no-pager

# Check if port is in use:
sudo ss -tlnp | grep 8080

# Test JAR directly:
sudo -u deploy java -jar /opt/speakit/backend/TextToSpeechApplication-0.0.1-SNAPSHOT.jar
```

### NGINX Proxy Errors

```bash
# Test NGINX config:
sudo nginx -t

# Check error logs:
sudo tail -50 /var/log/nginx/error.log

# Test proxy connection:
curl -v http://127.0.0.1:8080/api/tts/voices
```

### SSL Certificate Issues

```bash
# Check certificate status:
sudo certbot certificates

# View renewal logs:
sudo journalctl -u certbot -n 50

# Force renewal:
sudo certbot renew --force-renewal
```

### Recovery from Broken Deployment

```bash
# 1. Stop service:
sudo systemctl stop speakit-backend

# 2. Check backup:
ls -la /opt/speakit/backup/

# 3. Restore from backup:
sudo systemctl stop speakit-backend
sudo cp /opt/speakit/backup/TextToSpeechApplication-YYYYMMDD_HHMMSS.jar \
    /opt/speakit/backend/TextToSpeechApplication-0.0.1-SNAPSHOT.jar
sudo systemctl start speakit-backend
```

---

## Quick Reference Commands

```bash
# === SSH ===
ssh -i key.pem deploy@your-ip

# === Service Management ===
sudo systemctl status speakit-backend
sudo systemctl restart speakit-backend
sudo journalctl -u speakit-backend -f

# === NGINX ===
sudo nginx -t
sudo systemctl restart nginx

# === SSL ===
sudo certbot renew --dry-run

# === Monitoring ===
sudo tail -f /var/log/auth.log | grep Failed
sudo ss -tlnp

# === Deployment ===
sudo /opt/speakit/deploy.sh /path/to/new/jar
```

---

## Architecture Diagram (Final)

```
INTERNET (Users)
     │
     ▼
┌────────────────────────┐
│  OCI CLOUD FIREWALL    │
│  ├─ 443/TCP (HTTPS)    │  Only 3 ports exposed
│  ├─ 80/TCP (HTTP)      │  to internet
│  └─ 22/TCP (SSH)*       │  (* from YOUR_IP only)
└────────────────────────┘
     │
     ▼
┌────────────────────────┐
│  UBUNTU SERVER         │
│  ┌──────────────────┐  │
│  │  UFW Firewall    │  │  OS-level firewall
│  │  (Defense Layer) │  │  blocking all else
│  └──────────────────┘  │
│         │              │
│  ┌──────▼───────────┐  │
│  │     NGINX        │  │  Reverse proxy
│  │  (SSL + Headers) │  │  + Security headers
│  └──────┬───────────┘  │
│         │ 127.0.0.1     │
│  ┌──────▼───────────┐  │
│  │   Spring Boot    │  │  Internal binding
│  │   (Port 8080)    │  │  Not publicly accessible
│  └──────┬───────────┘  │
│         │              │
│  ┌──────▼───────────┐  │
│  │   PostgreSQL      │  │  External service
│  │   (Supabase)     │  │  via env vars
│  └──────────────────┘  │
└────────────────────────┘
     │
     ▼
┌────────────────────────┐
│  EXTERNAL APIS        │
│  ├─ AWS Polly (TTS)  │
│  └─ Supabase (DB)     │
└────────────────────────┘
```

---

**Document Version:** 1.0
**Last Updated:** 2026-05-14
**Author:** Claude (Senior DevOps Engineer)
