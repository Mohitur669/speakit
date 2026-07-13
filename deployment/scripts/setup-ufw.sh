#!/bin/bash
#
# SpeakIt UFW Firewall Setup
# Run this script ON THE SERVER after initial Ubuntu setup
#

set -e

echo "=== SpeakIt UFW Firewall Setup ==="
echo "This script will configure UFW with secure defaults"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Install UFW if not present
if ! command -v ufw &> /dev/null; then
    echo "Installing UFW..."
    apt update && apt install -y ufw
fi

# Reset to defaults (start fresh)
echo "Resetting UFW to defaults..."
ufw --force reset

# Set default policies
echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Allow SSH (with rate limiting to prevent brute force)
echo "Configuring SSH..."
ufw limit 22/tcp comment 'SSH with rate limiting (6 connections/minute)'

# Allow HTTP (required for Let's Encrypt)
echo "Configuring HTTP..."
ufw allow 80/tcp comment 'HTTP for Let'\''s Encrypt certificate renewal'

# Allow HTTPS
echo "Configuring HTTPS..."
ufw allow 443/tcp comment 'HTTPS secure web traffic'

# Enable UFW
echo "Enabling UFW..."
echo "y" | ufw enable

# Show status
echo ""
echo "=== UFW Status ==="
ufw status verbose

# Save rules
echo "y" | ufw reload

echo ""
echo "=== Setup Complete ==="
echo "Only the following ports are open:"
echo "  - 22/tcp (SSH - rate limited)"
echo "  - 80/tcp (HTTP - Let's Encrypt)"
echo "  - 443/tcp (HTTPS)"
echo ""
echo "IMPORTANT: Ensure you have SSH key access before enabling UFW!"
echo "To check SSH access, run: ssh -i /path/to/key deploy@localhost"