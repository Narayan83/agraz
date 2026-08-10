# Deploy latest backend + admin to agrazllp.com VPS
# Run in PowerShell, then enter root password when prompted.
$ErrorActionPreference = "Stop"
$Root = "d:\fullstack\others\app_agraz"
$HostName = "88.222.242.192"
$Bin = Join-Path $Root "agraz_backend\release\agraz_backend"
$Dist = Join-Path $Root "agraz_admin\dist"

if (-not (Test-Path $Bin)) { throw "Missing backend binary: $Bin" }
if (-not (Test-Path (Join-Path $Dist "index.html"))) { throw "Missing admin build: $Dist" }

Write-Host "==> Upload backend"
scp -P 22 -o StrictHostKeyChecking=accept-new $Bin "root@${HostName}:/root/agraz_backend.new"

Write-Host "==> Upload admin dist"
scp -P 22 -o StrictHostKeyChecking=accept-new -r $Dist "root@${HostName}:/root/agraz_admin_dist.new"

Write-Host "==> Install on server"
ssh -p 22 -o StrictHostKeyChecking=accept-new "root@$HostName" @'
set -euo pipefail
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
curl -s -o /dev/null -w "API HTTP %{http_code}\n" https://agrazllp.com/api/ || true
curl -s -o /dev/null -w "Market agents HTTP %{http_code}\n" https://agrazllp.com/api/market/agents || true
echo "Admin: https://agrazllp.com/agraz_admin/"
echo "Done."
'@
