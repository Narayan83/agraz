#!/usr/bin/env bash
# Run on VPS as root after uploading the vps-bundle via SFTP.
# Usage: sudo bash vps_setup.sh [path-to-bundle-dir]
set -euo pipefail

BUNDLE="${1:-/root/vps-bundle}"
APP_DIR="/opt/agraz"
ADMIN_DIR="/var/www/agrazllp.com/agraz_web/agraz_admin"
NGINX_SITE="/etc/nginx/sites-available/agrazllp.com-ssl"
SQL_FILE="$BUNDLE/agraz.sql"

DB_NAME="${DB_NAME:-agraz}"
DB_USER="${DB_USER:-agraz_user}"
DB_PASS="${DB_PASS:-}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

if [[ ! -d "$BUNDLE" ]]; then
  echo "Bundle not found: $BUNDLE"
  echo "Upload vps-bundle/ to /root/vps-bundle first."
  exit 1
fi

if [[ -z "$DB_PASS" ]]; then
  DB_PASS="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
  echo "Generated DB password for $DB_USER: $DB_PASS"
  echo "Save this password — it is written to $APP_DIR/.env"
fi

JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 48)}"

echo "==> PostgreSQL"
if ! command -v psql >/dev/null; then
  apt-get update -qq
  apt-get install -y postgresql postgresql-contrib
fi
systemctl enable --now postgresql

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

if [[ -f "$SQL_FILE" ]]; then
  echo "Restoring $SQL_FILE ..."
  sudo -u postgres psql -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" "$DB_NAME" 2>/dev/null || true
  PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -f "$SQL_FILE"
  echo "Database restored."
else
  echo "WARN: $SQL_FILE not found — skipping DB restore."
fi

echo "==> Backend at $APP_DIR"
mkdir -p "$APP_DIR/uploads"
cp "$BUNDLE/agraz_backend" "$APP_DIR/agraz_backend"
chmod +x "$APP_DIR/agraz_backend"

if [[ -d "$BUNDLE/uploads" ]] && [[ -n "$(ls -A "$BUNDLE/uploads" 2>/dev/null || true)" ]]; then
  cp -a "$BUNDLE/uploads/." "$APP_DIR/uploads/"
fi

cat > "$APP_DIR/.env" <<EOF
PORT=8000
DB_CONNECTION_STRING=host=127.0.0.1 user=$DB_USER password=$DB_PASS dbname=$DB_NAME port=5432 sslmode=disable
JWT_SECRET=$JWT_SECRET
EOF
chmod 600 "$APP_DIR/.env"
chown -R www-data:www-data "$APP_DIR/uploads"
chown www-data:www-data "$APP_DIR/.env" "$APP_DIR/agraz_backend"

echo "==> systemd"
cp "$BUNDLE/agraz-backend.service" /etc/systemd/system/agraz.service
systemctl daemon-reload
systemctl enable agraz
systemctl restart agraz
sleep 2
systemctl --no-pager status agraz || true

echo "==> Admin SPA"
mkdir -p "$ADMIN_DIR"
if [[ -d "$BUNDLE/agraz_admin" ]]; then
  rm -rf "${ADMIN_DIR:?}/"*
  cp -a "$BUNDLE/agraz_admin/." "$ADMIN_DIR/"
  chown -R www-data:www-data "$ADMIN_DIR"
  echo "Admin files deployed to $ADMIN_DIR"
else
  echo "WARN: $BUNDLE/agraz_admin not found — upload admin build separately."
fi

echo "==> Nginx"
if [[ -f "$BUNDLE/nginx-agrazllp.com-ssl.conf" ]]; then
  cp "$BUNDLE/nginx-agrazllp.com-ssl.conf" "$NGINX_SITE"
  nginx -t
  systemctl reload nginx
  echo "Nginx reloaded."
fi

echo "==> Firewall (UFW)"
if command -v ufw >/dev/null; then
  ufw default deny incoming || true
  ufw default allow outgoing || true
  ufw allow 22/tcp || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  ufw --force enable || true
  ufw status || true
fi

echo ""
echo "=== Deploy complete ==="
echo "API:    https://agrazllp.com/api/"
echo "Admin:  https://agrazllp.com/agraz_admin/"
echo "Logs:   journalctl -u agraz -f"
echo ""
echo "Test login:"
echo "  curl -s -X POST https://agrazllp.com/api/login -H 'Content-Type: application/json' -d '{\"email\":\"YOUR_EMAIL\",\"password\":\"YOUR_PASS\"}'"
