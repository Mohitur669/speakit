#!/bin/bash
#
# SpeakIt Server Initial Setup Script
# Run this script ON THE SERVER as root after first SSH login
# This script automates the initial server hardening
#

set -e

echo "=== SpeakIt Server Initial Setup ==="
echo "This script will perform initial server hardening"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# ============================================
# Step 1: Update System
# ============================================
echo "Step 1: Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# ============================================
# Step 2: Create Deploy User
# ============================================
echo "Step 2: Creating deploy user..."
if ! id deploy &>/dev/null; then
    adduser --disabled-password --gecos "" deploy
    usermod -aG sudo deploy
    usermod -aG adm deploy
    echo "Deploy user created"
else
    echo "Deploy user already exists"
fi

# ============================================
# Step 3: Copy SSH Keys
# ============================================
echo "Step 3: Setting up SSH keys for deploy user..."
if [ -f /home/opc/.ssh/authorized_keys ]; then
    mkdir -p /home/deploy/.ssh
    cp /home/opc/.ssh/authorized_keys /home/deploy/.ssh/
    chmod 700 /home/deploy/.ssh
    chmod 600 /home/deploy/.ssh/authorized_keys
    chown -R deploy:deploy /home/deploy/.ssh
    echo "SSH keys copied"
else
    echo "WARNING: No SSH keys found for opc user"
fi

# ============================================
# Step 4: Create Directories
# ============================================
echo "Step 4: Creating application directories..."

# SEC-01 FIX (CWE-276): Keep /opt/speakit owned by root so that the low-privileged
# 'deploy' user cannot replace cron-executed scripts inside this directory.
# Only the /opt/speakit/backend subdirectory is handed over to 'deploy'.
mkdir -p /opt/speakit/backend
mkdir -p /opt/speakit/backend/logs
mkdir -p /opt/speakit/backend/tmp
mkdir -p /opt/speakit/config
mkdir -p /opt/speakit/backup
chown root:root /opt/speakit
chmod 755 /opt/speakit
chown -R deploy:deploy /opt/speakit/backend
chown -R deploy:deploy /opt/speakit/config
chown -R deploy:deploy /opt/speakit/backup
chmod -R 750 /opt/speakit/backend

# ============================================
# Step 5: Install Essential Packages
# ============================================
echo "Step 5: Installing security packages..."
apt install -y \
    unattended-upgrades \
    fail2ban \
    ufw \
    nginx \
    certbot \
    python3-certbot-nginx \
    auditd

# ============================================
# Step 6: Configure Automatic Updates
# ============================================
echo "Step 6: Configuring automatic security updates..."

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# ============================================
# Step 7: Configure Fail2Ban
# ============================================
echo "Step 7: Configuring Fail2Ban..."

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 86400
findtime = 3600
maxretry = 10

[sshd]
enabled = true
port = 22
action = iptables-multiport
logpath = /var/log/auth.log
EOF

systemctl enable fail2ban
systemctl start fail2ban

# ============================================
# Step 8: Configure UFW
# ============================================
echo "Step 8: Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

# ============================================
# Step 9: Install Java 21
# ============================================
echo "Step 9: Installing Java 21..."
apt install -y openjdk-21-jdk

# Verify Java
java -version
echo "Java installed at: $(which java)"

# ============================================
# Step 10: Copy Scripts
# ============================================
echo "Step 10: Copying deployment scripts..."

# Copy deploy script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/deploy.sh" ]; then
    cp "$SCRIPT_DIR/deploy.sh" /opt/speakit/deploy.sh
    chmod 750 /opt/speakit/deploy.sh
    chown root:deploy /opt/speakit/deploy.sh
fi

# Copy monitor script
if [ -f "$SCRIPT_DIR/monitor.sh" ]; then
    cp "$SCRIPT_DIR/monitor.sh" /opt/speakit/monitor.sh
    chmod 750 /opt/speakit/monitor.sh
    chown root:root /opt/speakit/monitor.sh
fi

# ============================================
# Step 11: Create SSH Banner
# ============================================
echo "Step 11: Creating SSH banner..."

cat > /etc/ssh/banner << 'EOF'
************************************************************
     AUTHORIZED ACCESS ONLY
     This system is for authorized use only.
     Individuals using this computer system without
     authority or in excess of their authority are subject
     to having all their activities monitored and recorded.
************************************************************
EOF
chmod 644 /etc/ssh/banner

# ============================================
# Step 12: Cron Setup
# ============================================
echo "Step 12: Setting up monitoring cron..."
(crontab -l 2>/dev/null || true; echo "* * * * * /opt/speakit/monitor.sh") | crontab -

# ============================================
# Summary
# ============================================
echo ""
echo "=== Initial Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Verify SSH access for deploy user: ssh -i /path/to/key deploy@<your-ip>"
echo "  2. Configure SSH hardening (see deployment/configs/hardened-sshd_config)"
echo "  3. Create environment file at /opt/speakit/config/.env.backend"
echo "  4. Deploy Spring Boot JAR"
echo "  5. Configure NGINX with SSL"
echo ""
echo "Server is now ready for deployment!"