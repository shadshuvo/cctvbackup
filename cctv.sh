#!/bin/bash

# ==============================================================================
# CCTV Storage Manager & Google Drive Sync
# Author: Shadman Shuvo
# Description: Moves CCTV footage from local aaPanel storage to Google Drive,
#              manages retention policies, and sends Telegram alerts.
#
# Usage:
#   Set the following environment variables before running, or export them
#   from a secure, non-committed .env file:
#
#     TELEGRAM_BOT_TOKEN  - Your Telegram Bot token
#     TELEGRAM_CHAT_ID    - Your Telegram Chat ID
#
# Cron Example (01:30 AM Daily):
#   30 1 * * * bash /www/wwwroot/default/cctv/cctv.sh
# ==============================================================================

# --- 1. Configuration (Replace with your actual paths) ---
SOURCE_DIR="/www/wwwroot/default/cctv/main"
CONFIG_PATH="/www/wwwroot/default/cctv/rclone.conf"
REMOTE_NAME="gdrive-remote" # Matches your rclone.conf [remote-name]
REMOTE_DIR="$REMOTE_NAME:Scripts/cctv"

# Log Management
LOG_DIR="/www/wwwroot/default/cctv/logs"
LOG_FILE_NAME="cctv_manager_$(date +%Y-%m-%d).log"
LOG_FILE="${LOG_DIR}/${LOG_FILE_NAME}"

# --- 2. Maintenance & Cleanup ---
mkdir -p "$LOG_DIR"

# Notifications — loaded from environment variables for security.
# Set these in your shell profile, cron environment, or a sourced .env file.
# Never hard-code these values here.
# Validated after log directory setup so any failure is captured in the log.
if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    echo "$(date) ERROR: TELEGRAM_BOT_TOKEN environment variable is not set." >> "$LOG_FILE"
    exit 1
fi
if [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "$(date) ERROR: TELEGRAM_CHAT_ID environment variable is not set." >> "$LOG_FILE"
    exit 1
fi

# Remove local logs older than 7 days
find "$LOG_DIR" -type f -name "*.log" -mtime +7 -exec rm -f {} \;

# Telegram Alert Function
send_alert() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="🚨 *CCTV Sync Error* 🚨%0A%0A${message}" \
        -d parse_mode="Markdown" > /dev/null
}

echo "Starting CCTV Manager at $(date)" >> "$LOG_FILE"

# --- 3. Cloud Retention (30-Day Policy) ---
# Removes files from GDrive older than 30 days
if ! rclone delete "$REMOTE_DIR" --config="$CONFIG_PATH" --min-age 30d >> "$LOG_FILE" 2>&1; then
    send_alert "Failed to execute 30-day cloud cleanup."
fi
rclone rmdirs "$REMOTE_DIR" --config="$CONFIG_PATH" --leave-root >> "$LOG_FILE" 2>&1

# --- 4. Data Migration ---
# Moves files to cloud with I/O and Bandwidth throttling.
# Note: `ionice -c 3` (idle I/O class) may require root or CAP_SYS_ADMIN.
# If running as a non-root user, ionice will be skipped by the kernel but
# the transfer will still proceed at normal I/O priority via nice.
if nice -n 19 ionice -c 3 rclone move "$SOURCE_DIR" "$REMOTE_DIR" \
    --config="$CONFIG_PATH" \
    --min-age 15m \
    --delete-empty-src-dirs \
    --transfers 4 \
    --bwlimit 15M \
    --drive-chunk-size 32M \
    --log-file "$LOG_FILE" \
    --log-level INFO; then

    echo "Sync Successful." >> "$LOG_FILE"
else
    send_alert "Rclone failed to move footage. Check server storage!"
fi

# --- 5. Off-site Log Backup ---
rclone copy "$LOG_FILE" "$REMOTE_DIR/Logs" --config="$CONFIG_PATH" >> /dev/null 2>&1

echo "Task Completed: $(date)" >> "$LOG_FILE"
echo "-----------------------------------" >> "$LOG_FILE"
