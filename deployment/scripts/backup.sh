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