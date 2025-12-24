#!/bin/bash
# PostgreSQL backup script for AfyaFit
# This script creates a timestamped backup of the PostgreSQL database

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/afyafit_backup_${TIMESTAMP}.sql.gz"

# Database connection (read from secrets or environment)
DB_USER="${POSTGRES_USER:-$(cat /run/secrets/postgres_user 2>/dev/null || echo 'postgres')}"
DB_NAME="${POSTGRES_DB:-$(cat /run/secrets/postgres_db 2>/dev/null || echo 'afyafit')}"
DB_HOST="${POSTGRES_HOST:-postgres}"
DB_PORT="${POSTGRES_PORT:-5432}"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Create backup
echo "Creating backup: ${BACKUP_FILE}"
PGPASSWORD="${POSTGRES_PASSWORD:-$(cat /run/secrets/postgres_password 2>/dev/null || echo '')}" \
  pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
  --no-owner --no-acl | gzip > "${BACKUP_FILE}"

# Verify backup was created
if [ -f "${BACKUP_FILE}" ] && [ -s "${BACKUP_FILE}" ]; then
  echo "Backup created successfully: ${BACKUP_FILE}"
  echo "Backup size: $(du -h "${BACKUP_FILE}" | cut -f1)"
else
  echo "ERROR: Backup file was not created or is empty"
  exit 1
fi

# Remove old backups (older than RETENTION_DAYS)
echo "Cleaning up backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "afyafit_backup_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete

echo "Backup completed successfully"

