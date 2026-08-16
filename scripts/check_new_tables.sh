#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRED="$ROOT/.vps_credentials"
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  export "$line"
done < "$CRED"
export SSHPASS="${VPS_PASSWORD:?}"
HOST="${VPS_USER:-root}@${VPS_HOST:-88.222.242.192}"
PORT="${VPS_PORT:-22}"
sshpass -e ssh -o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no -p "$PORT" "$HOST" \
  "sudo -u postgres psql -d agraz -c \"SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND (tablename LIKE 'diary_%' OR tablename LIKE 'future_plan%' OR tablename IN ('labor_extras','labor_work_entries')) ORDER BY 1;\""
