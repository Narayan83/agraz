#!/usr/bin/env bash
# Build backend + bundle everything for SFTP upload to VPS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADMIN_ROOT="$(cd "$ROOT/../agraz_admin" && pwd)"
OUT="$ROOT/release/vps-bundle"

cd "$ROOT"
bash scripts/build_vps.sh

echo "Building admin SPA..."
cd "$ADMIN_ROOT"
npm run build --silent

echo "Packaging vps-bundle..."
rm -rf "$OUT"
mkdir -p "$OUT/uploads" "$OUT/agraz_admin"

cp "$ROOT/release/agraz-backend-linux-amd64" "$OUT/agraz_backend"
cp "$ROOT/deploy/agraz-backend.service" "$OUT/"
cp "$ROOT/deploy/nginx-agrazllp.com-ssl.conf" "$OUT/"
cp "$ROOT/scripts/vps_setup.sh" "$OUT/"
# Use newest backup if present
SQL_SRC="$(ls -t "$ROOT/backups"/agraz_*.sql 2>/dev/null | head -1)"
if [[ -z "$SQL_SRC" ]]; then
  echo "ERROR: No agraz_*.sql in backups/"
  exit 1
fi
cp "$SQL_SRC" "$OUT/agraz.sql"
echo "Using SQL dump: $SQL_SRC"

if [[ -d "$ROOT/uploads" ]] && [[ -n "$(ls -A "$ROOT/uploads" 2>/dev/null || true)" ]]; then
  cp -a "$ROOT/uploads/." "$OUT/uploads/"
fi

cp -a "$ADMIN_ROOT/dist/." "$OUT/agraz_admin/"

chmod +x "$OUT/vps_setup.sh" "$OUT/agraz_backend"

STAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE="$ROOT/release/vps-bundle-${STAMP}.tar.gz"
tar -czf "$ARCHIVE" -C "$ROOT/release" vps-bundle

echo ""
echo "Ready to upload:"
echo "  Folder:  $OUT"
echo "  Archive: $ARCHIVE"
echo ""
echo "SFTP upload vps-bundle/ to /root/vps-bundle on VPS, then SSH:"
echo "  ssh root@88.222.242.192"
echo "  cd /root/vps-bundle && bash vps_setup.sh"
