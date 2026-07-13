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