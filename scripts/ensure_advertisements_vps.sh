#!/bin/bash
# Create advertisements table + seed on live VPS (idempotent).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRED="$ROOT/.vps_credentials"
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  export "$line"
done < "$CRED"
export SSHPASS="${VPS_PASSWORD:?VPS_PASSWORD missing}"
HOST="${VPS_USER:-root}@${VPS_HOST:-88.222.242.192}"
PORT="${VPS_PORT:-22}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no"

echo "==> Create table + grants"
sshpass -e ssh -p "$PORT" $SSH_OPTS "$HOST" "sudo -u postgres psql -d agraz -v ON_ERROR_STOP=1" <<'SQL'
CREATE TABLE IF NOT EXISTS advertisements (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL DEFAULT 1,
  title VARCHAR(80) NOT NULL,
  subtitle VARCHAR(120),
  tag VARCHAR(32),
  image_url TEXT NOT NULL,
  link_type VARCHAR(32) NOT NULL DEFAULT 'none',
  link_value VARCHAR(512),
  sort_order BIGINT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  impressions BIGINT NOT NULL DEFAULT 0,
  clicks BIGINT NOT NULL DEFAULT 0,
  created_by BIGINT,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_advertisements_tenant_id ON advertisements (tenant_id);
CREATE INDEX IF NOT EXISTS idx_advertisements_sort_order ON advertisements (sort_order);
CREATE INDEX IF NOT EXISTS idx_advertisements_is_active ON advertisements (is_active);
CREATE INDEX IF NOT EXISTS idx_advertisements_start_date ON advertisements (start_date);
CREATE INDEX IF NOT EXISTS idx_advertisements_end_date ON advertisements (end_date);
CREATE INDEX IF NOT EXISTS idx_advertisements_created_by ON advertisements (created_by);
CREATE INDEX IF NOT EXISTS idx_advertisements_deleted_at ON advertisements (deleted_at);
GRANT SELECT, INSERT, UPDATE, DELETE ON advertisements TO agraz_user;
GRANT USAGE, SELECT ON SEQUENCE advertisements_id_seq TO agraz_user;
SQL

echo "==> Upload dir, seed row, restart"
sshpass -e ssh -p "$PORT" $SSH_OPTS "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p /var/www/agraz_backend/uploads/advertisements
if [ ! -s /var/www/agraz_backend/uploads/advertisements/default-smart-farming.jpg ]; then
  python3 - <<'PY'
from pathlib import Path
jpeg = bytes.fromhex(
  "ffd8ffe000104a46494600010100000100010000ffdb004300080606070605080707"
  "070909080a0c140d0c0b0b0c1912130f141d1a1f1e1d1a1c1c20242e2720222c231c"
  "1c2837292c30313434341f27393d38323c2e333432ffdb0043010909090c0b0c180d"
  "0d1832211c2132323232323232323232323232323232323232323232323232323232"
  "323232323232323232323232323232323232ffc00011080001000103011100021101"
  "031101ffc40014000100000000000000000000000000000008ffc400141001000000"
  "00000000000000000000000000ffda000c0301000210031000003f00bf80ffd9"
)
Path("/var/www/agraz_backend/uploads/advertisements/default-smart-farming.jpg").write_bytes(jpeg)
print("wrote placeholder jpeg")
PY
fi
chown -R www-data:www-data /var/www/agraz_backend/uploads/advertisements
sudo -u postgres psql -d agraz -v ON_ERROR_STOP=1 -c "
INSERT INTO advertisements (tenant_id, title, subtitle, tag, image_url, link_type, sort_order, is_active, impressions, clicks, created_at, updated_at)
SELECT 1, 'Smart Farming, Simplified', 'Agriculture ERP for modern farms', 'AD', '/uploads/advertisements/default-smart-farming.jpg', 'none', 10, true, 0, 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM advertisements WHERE tenant_id = 1 AND deleted_at IS NULL);
"
systemctl restart agraz
sleep 2
systemctl --no-pager is-active agraz
curl -s -o /dev/null -w "active ads HTTP %{http_code}\n" https://agrazllp.com/api/advertisements/active
curl -s https://agrazllp.com/api/advertisements/active
echo
REMOTE

echo "Done."
