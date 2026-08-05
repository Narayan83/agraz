#!/usr/bin/env bash
# One-shot VPS update: backend binary + admin SPA.
# Usage (from Git Bash or WSL):
#   bash scripts/push_vps_update.sh
# You will be prompted for the root SSH password. .env is never uploaded.
set -euo pipefail

HOST="88.222.242.192"
PORT="22"
USER="root"
APP="/var/www/agraz_backend"
ADMIN="/var/www/agrazllp.com/agraz_web/agraz_admin"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/agraz_backend/release/agraz_backend"
DIST="$ROOT/agraz_admin/dist"

if [[ ! -f "$BIN" ]]; then
  echo "Missing binary: $BIN"
  echo "Build first: cd agraz_backend && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o release/agraz_backend ."
  exit 1
fi
if [[ ! -d "$DIST" ]] || [[ ! -f "$DIST/index.html" ]]; then
  echo "Missing admin build: $DIST"
  echo "Build first: cd agraz_admin && npm run build"
  exit 1
fi

SSH=(ssh -p "$PORT" -o StrictHostKeyChecking=accept-new "$USER@$HOST")
SCP=(scp -P "$PORT" -o StrictHostKeyChecking=accept-new)

echo "==> Upload backend binary"
"${SCP[@]}" "$BIN" "$USER@$HOST:/root/agraz_backend.new"

echo "==> Upload admin dist"
"${SCP[@]}" -r "$DIST" "$USER@$HOST:/root/agraz_admin_dist.new"

echo "==> Install on VPS (stop / replace / start; .env untouched)"
"${SSH[@]}" bash -s <<EOF
set -euo pipefail
systemctl stop agraz
cp "$APP/agraz_backend" "$APP/agraz_backend.bak"
mv /root/agraz_backend.new "$APP/agraz_backend"
chmod +x "$APP/agraz_backend"
chown www-data:www-data "$APP/agraz_backend"

rm -rf "${ADMIN}.bak"
if [[ -d "$ADMIN" ]]; then mv "$ADMIN" "${ADMIN}.bak"; fi
mkdir -p "$ADMIN"
cp -a /root/agraz_admin_dist.new/. "$ADMIN/"
chown -R www-data:www-data "$ADMIN"
rm -rf /root/agraz_admin_dist.new

systemctl start agraz
sleep 2
systemctl --no-pager status agraz || true
journalctl -u agraz -n 30 --no-pager || true
curl -s -o /dev/null -w "API HTTP %{http_code}\n" https://agrazllp.com/api/ || true
echo "Admin: https://agrazllp.com/agraz_admin/"
echo "Done. .env was not modified."
EOF
