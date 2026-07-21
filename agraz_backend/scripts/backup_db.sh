#!/usr/bin/env bash
# Backup agraz PostgreSQL (server in WSL). Run from WSL, not pgAdmin on Windows.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_DIR/agraz_${STAMP}.sql"

# Defaults match .env; override with env vars if needed
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-agraz}"
PGPASSWORD="${PGPASSWORD:-postpass}"

if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  line="$(grep -E '^[[:space:]]*DB_CONNECTION_STRING[[:space:]]*=' "$ROOT/.env" | head -1 || true)"
  if [[ -n "$line" ]]; then
    conn="$(echo "$line" | sed -E 's/^[[:space:]]*DB_CONNECTION_STRING[[:space:]]*=[[:space:]]*"?([^"]*)"?/\1/')"
    for tok in $conn; do
      case "$tok" in
        host=*) PGHOST="${tok#host=}" ;;
        port=*) PGPORT="${tok#port=}" ;;
        user=*) PGUSER="${tok#user=}" ;;
        password=*) PGPASSWORD="${tok#password=}" ;;
        dbname=*) PGDATABASE="${tok#dbname=}" ;;
      esac
    done
  fi
fi

mkdir -p "$BACKUP_DIR"
export PGPASSWORD

echo "Dumping $PGDATABASE @ $PGHOST:$PGPORT ..."
pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
  -F p --no-owner --no-acl -f "$OUT"

unset PGPASSWORD
echo "OK: $OUT ($(du -h "$OUT" | cut -f1))"
