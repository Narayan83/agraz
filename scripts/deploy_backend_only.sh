#!/usr/bin/env bash
# Backend-only VPS deploy using .vps_credentials
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Prefer Windows mount path when run under WSL against D: repo
if [[ ! -f "$ROOT/.vps_credentials" ]] && [[ -f /mnt/d/fullstack/others/app_agraz/.vps_credentials ]]; then
  ROOT=/mnt/d/fullstack/others/app_agraz
fi
CRED="$ROOT/.vps_credentials"
BIN="$ROOT/agraz_backend/release/agraz_backend"

echo "ROOT=$ROOT"
test -f "$CRED" || { echo "missing credentials"; exit 1; }
test -f "$BIN" || { echo "missing binary $BIN"; exit 1; }

# strip CR from Windows-edited credential file
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  export "$line"
done < "$CRED"

HOST="${VPS_USER:-root}@${VPS_HOST:-88.222.242.192}"
PORT="${VPS_PORT:-22}"
export SSHPASS="${VPS_PASSWORD:?VPS_PASSWORD missing}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=20"

echo "==> Upload backend ($(wc -c < "$BIN") bytes) to $HOST"
sshpass -e scp -P "$PORT" $SSH_OPTS "$BIN" "$HOST:/root/agraz_backend.new"

echo "==> Install + restart"
sshpass -e ssh -p "$PORT" $SSH_OPTS "$HOST" 'set -euo pipefail
APP=/var/www/agraz_backend
systemctl stop agraz
cp "$APP/agraz_backend" "$APP/agraz_backend.bak"
mv /root/agraz_backend.new "$APP/agraz_backend"
chmod +x "$APP/agraz_backend"
chown www-data:www-data "$APP/agraz_backend"
systemctl start agraz
sleep 2
systemctl is-active agraz
systemctl --no-pager status agraz | head -n 12
journalctl -u agraz -n 25 --no-page
curl -s -o /dev/null -w "API HTTP %{http_code}\n" https://agrazllp.com/api/ || true
echo "Done. .env not modified."
'
