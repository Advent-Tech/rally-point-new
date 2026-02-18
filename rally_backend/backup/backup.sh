#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/backups
BACKUP_FILE="$BACKUP_DIR/rally_point_$TIMESTAMP.sql.gz"

echo "[$(date)] Starting backup..."

# Create backup with pg_dump, compress with gzip
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -U "$POSTGRES_USER" \
  "$POSTGRES_DB" | gzip > "$BACKUP_FILE"

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup created: $BACKUP_FILE ($SIZE)"

# Keep only last 7 days of backups
DELETED=$(find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -print -delete | wc -l)
if [ "$DELETED" -gt 0 ]; then
  echo "[$(date)] Cleaned up $DELETED old backup(s)"
fi

echo "[$(date)] Backup complete. Current backups:"
ls -lh $BACKUP_DIR/*.sql.gz 2>/dev/null || echo "  (none)"
