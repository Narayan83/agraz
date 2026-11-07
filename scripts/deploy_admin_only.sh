#!/usr/bin/env bash
# Admin-only VPS deploy using local .vps_credentials (gitignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# WSL path if invoked from /mnt/d
if [[ ! -f "$ROOT/.vps_credentials" ]] && [[ -f /mnt/d/fullstack/others/app_agraz/.vps_credentials ]]; then
  ROOT=/mnt/d/fullstack/others/app_agraz
fi
CRED="$ROOT/.vps_credentials"
DIST="$ROOT/agraz_admin/dist"

if [[ ! -f "$CRED" ]]; then
  echo "Missing $CRED"
  exit 1
fi
if [[ ! -f "$DIST/index.html" ]]; then
  echo "Missing admin build: $DIST"
  exit 1
fi

set -a
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  export "$line"
done < "$CRED"
set +a

HOST="${VPS_USER:-root}@${VPS_HOST:-88.222.242.192}"
PORT="${VPS_PORT:-22}"
export SSHPASS="${VPS_PASSWORD:?VPS_PASSWORD missing in .vps_credentials}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no"

echo "==> Upload admin dist"
sshpass -e scp -P "$PORT" $SSH_OPTS -r "$DIST" "$HOST:/root/agraz_admin_dist.new"

echo "==> Install on server"
sshpass -e ssh -p "$PORT" $SSH_OPTS "$HOST" 'set -euo pipefail
ADMIN=/var/www/agrazllp.com/agraz_web/agraz_admin
rm -rf "${ADMIN}.bak"
if [ -d "$ADMIN" ]; then mv "$ADMIN" "${ADMIN}.bak"; fi
mkdir -p "$ADMIN"
cp -a /root/agraz_admin_dist.new/. "$ADMIN/"
chown -R www-data:www-data "$ADMIN"
rm -rf /root/agraz_admin_dist.new
echo "Admin: https://agrazllp.com/agraz_admin/"
echo "Done. Backend untouched."
'
