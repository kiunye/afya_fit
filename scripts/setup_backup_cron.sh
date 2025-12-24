#!/bin/bash
# Setup automated PostgreSQL backups using cron
# This script adds a cron job to run daily backups

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup_postgres.sh"
CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"  # Default: 2 AM daily

# Check if backup script exists
if [ ! -f "${BACKUP_SCRIPT}" ]; then
  echo "ERROR: Backup script not found: ${BACKUP_SCRIPT}"
  exit 1
fi

# Make sure backup script is executable
chmod +x "${BACKUP_SCRIPT}"

# Create cron job entry
CRON_ENTRY="${CRON_SCHEDULE} ${BACKUP_SCRIPT} >> /var/log/postgres_backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "${BACKUP_SCRIPT}"; then
  echo "Cron job already exists for ${BACKUP_SCRIPT}"
  echo "Current crontab:"
  crontab -l | grep "${BACKUP_SCRIPT}"
else
  # Add cron job
  (crontab -l 2>/dev/null; echo "${CRON_ENTRY}") | crontab -
  echo "Cron job added successfully:"
  echo "${CRON_ENTRY}"
fi

echo "Backup automation setup complete"
echo "Backups will run at: ${CRON_SCHEDULE}"

