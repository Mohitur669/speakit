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