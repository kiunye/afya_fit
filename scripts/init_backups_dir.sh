#!/bin/bash
# Initialize backups directory with proper permissions
# Run this before starting docker-compose for the first time

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Create backups directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Set proper permissions (readable/writable by postgres user in container)
# Note: The actual permissions will depend on your Docker setup
chmod 755 "${BACKUP_DIR}"

echo "Backups directory initialized: ${BACKUP_DIR}"
echo "Make sure this directory is mounted in docker-compose volumes"

