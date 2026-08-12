#!/bin/bash
# Deploy backend + admin using local .vps_credentials (gitignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRED="$ROOT/.vps_credentials"
BIN="$ROOT/agraz_backend/release/agraz_backend"
DIST="$ROOT/agraz_admin/dist"

if [[ ! -f "$CRED" ]]; then
  echo "Missing $CRED — create it with VPS_PASSWORD=..."
  exit 1
fi
# shellcheck disable=SC1090
set -a
# parse KEY=VALUE lines
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  export "$line"
done < "$CRED"
set +a

HOST="${VPS_USER:-root}@${VPS_HOST:-88.222.242.192}"
PORT="${VPS_PORT:-22}"
export SSHPASS="${VPS_PASSWORD:?VPS_PASSWORD missing in .vps_credentials}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no"

# WSL path if needed
if [[ ! -f "$BIN" ]] && [[ -f "/mnt/d/fullstack/others/app_agraz/agraz_backend/release/agraz_backend" ]]; then
  ROOT=/mnt/d/fullstack/others/app_agraz
  BIN="$ROOT/agraz_backend/release/agraz_backend"
  DIST="$ROOT/agraz_admin/dist"
fi

test -f "$BIN" || { echo "missing binary: $BIN"; exit 1; }
test -f "$DIST/index.html" || { echo "missing admin: $DIST"; exit 1; }

echo "==> Upload backend ($(wc -c < "$BIN") bytes)"
sshpass -e scp -P "$PORT" $SSH_OPTS "$BIN" "$HOST:/root/agraz_backend.new"

echo "==> Upload admin dist"
sshpass -e scp -P "$PORT" $SSH_OPTS -r "$DIST" "$HOST:/root/agraz_admin_dist.new"

echo "==> Install on server"
sshpass -e ssh -p "$PORT" $SSH_OPTS "$HOST" 'set -euo pipefail
APP=/var/www/agraz_backend
ADMIN=/var/www/agrazllp.com/agraz_web/agraz_admin
systemctl stop agraz
cp "$APP/agraz_backend" "$APP/agraz_backend.bak"
mv /root/agraz_backend.new "$APP/agraz_backend"
chmod +x "$APP/agraz_backend"
chown www-data:www-data "$APP/agraz_backend"
rm -rf "${ADMIN}.bak"
if [ -d "$ADMIN" ]; then mv "$ADMIN" "${ADMIN}.bak"; fi
mkdir -p "$ADMIN"
cp -a /root/agraz_admin_dist.new/. "$ADMIN/"
chown -R www-data:www-data "$ADMIN"
rm -rf /root/agraz_admin_dist.new
systemctl start agraz
sleep 2
systemctl --no-pager status agraz || true
journalctl -u agraz -n 40 --no-pager || true
curl -s -o /dev/null -w "API HTTP %{http_code}\n" https://agrazllp.com/api/ || true
echo "Admin: https://agrazllp.com/agraz_admin/"
echo "Done. .env was not modified."
'

echo "==> Verify organizations route (expect 401 without token)"
curl -s -o /dev/null -w "organizations %{http_code}\n" https://agrazllp.com/api/organizations || true
