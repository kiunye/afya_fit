#!/bin/bash
# PostgreSQL restore script for AfyaFit
# Usage: ./restore_postgres.sh <backup_file>

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <backup_file>"
  echo "Example: $0 /backups/afyafit_backup_20240101_120000.sql.gz"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "ERROR: Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

# Database connection (read from secrets or environment)
DB_USER="${POSTGRES_USER:-$(cat /run/secrets/postgres_user 2>/dev/null || echo 'postgres')}"
DB_NAME="${POSTGRES_DB:-$(cat /run/secrets/postgres_db 2>/dev/null || echo 'afyafit')}"
DB_HOST="${POSTGRES_HOST:-postgres}"
DB_PORT="${POSTGRES_PORT:-5432}"

# Confirm restore
echo "WARNING: This will restore the database from: ${BACKUP_FILE}"
echo "Database: ${DB_NAME} on ${DB_HOST}:${DB_PORT}"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "${confirm}" != "yes" ]; then
  echo "Restore cancelled"
  exit 0
fi

# Restore backup
echo "Restoring backup: ${BACKUP_FILE}"
PGPASSWORD="${POSTGRES_PASSWORD:-$(cat /run/secrets/postgres_password 2>/dev/null || echo '')}" \
  gunzip -c "${BACKUP_FILE}" | \
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"

echo "Restore completed successfully"

