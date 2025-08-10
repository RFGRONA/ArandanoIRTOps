#!/bin/bash
set -euo pipefail

# ==============================================================================
# BACKUP SCRIPT FOR POSTGRESQL AND MINIO
# Description: This script performs a dump of a PostgreSQL database running in
#              a Docker container, compresses it, uploads it to a MinIO bucket,
#              and stores a persistent log of the operation.
#              Logs older than 90 days are automatically deleted.
# Repository Version: 1.4
# ==============================================================================

# --- CONFIGURATION ---
DB_USER="${DB_USER:-arandano_user}"
DB_NAME="${DB_NAME:-arandano_db}"
DB_CONTAINER="${DB_CONTAINER:-arandano-postgres}"

# MinIO configuration
MINIO_ALIAS="${MINIO_ALIAS:-localminio}"
MINIO_BUCKET="${MINIO_BUCKET:-backups}"

# Temporary directory for storing backups before upload
BACKUP_DIR="${BACKUP_DIR:-/tmp}"

# Directory for persistent logs
LOG_DIR="${LOG_DIR:-/var/log/db_backups}"
mkdir -p "${LOG_DIR}"

# Number of days to keep logs
LOG_RETENTION_DAYS=90

# --- SCRIPT LOGIC (Do not modify below this line) ---

# Create timestamped filenames
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="backup-${TIMESTAMP}.sql.gz"
LOG_FILE="backup-${TIMESTAMP}.log"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"
LOG_PATH="${LOG_DIR}/${LOG_FILE}"

# Redirect all output to both console and log file
exec > >(tee -a "${LOG_PATH}") 2>&1

echo "----------------------------------------"
echo "Starting backup of the database: ${DB_NAME}"
echo "Timestamp: ${TIMESTAMP}"
echo "----------------------------------------"
echo "INFO: Backup file will be: ${BACKUP_FILE}"
echo "INFO: Log file stored at: ${LOG_PATH}"

# Run pg_dump inside the container, compress and save
if docker exec -u postgres "${DB_CONTAINER}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip > "${BACKUP_PATH}"; then
  echo "OK: Database backup and compression completed successfully."
else
  echo "ERROR: pg_dump or compression failed. Aborting."
  exit 1
fi

# Upload backup to MinIO
echo "INFO: Uploading backup to MinIO bucket '${MINIO_BUCKET}'..."
if mc cp "${BACKUP_PATH}" "${MINIO_ALIAS}/${MINIO_BUCKET}/"; then
  echo "OK: Backup uploaded to MinIO successfully."
else
  echo "ERROR: Failed to upload backup to MinIO."
  exit 1
fi

# Remove only the backup file, keep the log
echo "INFO: Removing local backup file..."
rm -f "${BACKUP_PATH}"

# Clean up old logs
echo "INFO: Cleaning logs older than ${LOG_RETENTION_DAYS} days..."
find "${LOG_DIR}" -type f -name "*.log" -mtime +${LOG_RETENTION_DAYS} -exec rm -f {} \;

echo "----------------------------------------"
echo "Backup process completed successfully!"
echo "Log saved at: ${LOG_PATH}"
echo "----------------------------------------"

exit 0