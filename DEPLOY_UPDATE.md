# Agraz VPS — update deploy guide

Use this for **routine updates** of backend + admin UI.  
When you want a deploy, say: **"update the VPS"** (or **"update backend"** / **"update admin"**).

Do **not** run `agraz_backend/scripts/vps_setup.sh` for updates — that path is for first install and can reset DB / `.env`.

---

## Server facts (non-secret)

| Item | Value |
|------|--------|
| SSH | `root@88.222.242.192` port `22` |
| Auth | password (kept private; type when prompted) |
| Backend app | `/var/www/agraz_backend` |
| Backend binary | `/var/www/agraz_backend/agraz_backend` |
| Backend `.env` | `/var/www/agraz_backend/.env` (**do not overwrite**) |
| Admin static | `/var/www/agrazllp.com/agraz_web/agraz_admin` |
| Upload staging | `/root/vps-bundle` (optional) |
| DB | PostgreSQL ready — `agraz` / `agraz_user` (password private) |
| Domain | `https://agrazllp.com` |
| API | `https://agrazllp.com/api/` |
| Admin URL | `https://agrazllp.com/agraz_admin/` |
| systemd | `agraz` |
| Restart | `systemctl restart agraz` |
| Logs | `journalctl -u agraz -f` |
| OS | Ubuntu 22.04 amd64 |
| Nginx + SSL | yes |
| Build style | prebuilt Linux `amd64` binary (build on PC) |

Local repo service file still mentions `/opt/agraz` — **live VPS uses `/var/www/agraz_backend`**. Prefer live paths above.

---

## Agent checklist (when user says “update”)

1. Confirm scope: **backend**, **admin**, or **both** (default: both).
2. Build locally on Windows (commands below).
3. User runs `scp` / `ssh` and enters the password (agent must not store or ask for the password in chat).
4. On VPS: stop service → replace binary (keep `.bak`) → start service.
5. If admin: upload `agraz_admin/dist` to admin static path.
6. Verify: `systemctl status agraz`, recent logs, HTTP check on API (and admin if updated).
7. Do **not** touch `.env`, PostgreSQL data, or Nginx unless user asks.

---

## 1) Update backend

### Build (PowerShell)

```powershell
cd d:\fullstack\others\app_agraz\agraz_backend
$env:CGO_ENABLED = "0"
$env:GOOS = "linux"
$env:GOARCH = "amd64"
go build -trimpath -ldflags="-s -w" -o release\agraz_backend .
```

Or from Git Bash / WSL:

```bash
cd /mnt/d/fullstack/others/app_agraz/agraz_backend   # adjust if path differs
bash scripts/build_vps.sh
# then copy: release/agraz-backend-linux-amd64 → upload as agraz_backend
```

### Upload

```powershell
scp -P 22 d:\fullstack\others\app_agraz\agraz_backend\release\agraz_backend root@88.222.242.192:/root/agraz_backend.new
```

### Install on VPS (SSH)

```bash
ssh -p 22 root@88.222.242.192
```

```bash
systemctl stop agraz
cp /var/www/agraz_backend/agraz_backend /var/www/agraz_backend/agraz_backend.bak
mv /root/agraz_backend.new /var/www/agraz_backend/agraz_backend
chmod +x /var/www/agraz_backend/agraz_backend
chown www-data:www-data /var/www/agraz_backend/agraz_backend
systemctl start agraz
systemctl status agraz --no-pager
journalctl -u agraz -n 50 --no-pager
```

### Quick API check

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://agrazllp.com/api/
```

Rollback if needed:

```bash
systemctl stop agraz
cp /var/www/agraz_backend/agraz_backend.bak /var/www/agraz_backend/agraz_backend
systemctl start agraz
```

---

## 2) Update admin UI

### Build (PowerShell)

```powershell
cd d:\fullstack\others\app_agraz\agraz_admin
npm run build
```

### Upload

```powershell
scp -r -P 22 d:\fullstack\others\app_agraz\agraz_admin\dist\* root@88.222.242.192:/var/www/agrazllp.com/agraz_web/agraz_admin/
```

Safer variant (sync into a temp folder, then swap on VPS) if you prefer zero-downtime / cleaner replace:

```powershell
scp -r -P 22 d:\fullstack\others\app_agraz\agraz_admin\dist root@88.222.242.192:/root/agraz_admin_dist.new
```

```bash
# on VPS
ADMIN=/var/www/agrazllp.com/agraz_web/agraz_admin
rm -rf "${ADMIN}.bak"
mv "$ADMIN" "${ADMIN}.bak" 2>/dev/null || true
mkdir -p "$ADMIN"
cp -a /root/agraz_admin_dist.new/. "$ADMIN/"
chown -R www-data:www-data "$ADMIN"
rm -rf /root/agraz_admin_dist.new
```

### Check

Open `https://agrazllp.com/agraz_admin/` (hard refresh if cached).

---

## 3) Both in one go

Preferred (after builds exist): from Git Bash or WSL at repo root:

```bash
bash scripts/push_vps_update.sh
```

Enter the SSH password when prompted. Script uploads binary + admin, swaps on VPS, restarts `agraz`, and **never** touches `.env`.

Manual equivalent:

1. Build backend + admin locally.  
2. `scp` binary → `/root/agraz_backend.new`  
3. `scp` admin dist → admin path (or temp + swap).  
4. SSH: stop/replace/start `agraz` as in §1.  
5. Verify API + admin URLs.

---

## Never on routine update

- Overwrite `/var/www/agraz_backend/.env`
- Drop / restore PostgreSQL unless user asks for a DB migration plan
- Run `vps_setup.sh`
- Change Nginx / SSL unless user asks
- Commit or paste SSH password / DB password

---

## First install only (reference)

Full first-time flow lives in:

- `agraz_backend/scripts/package_vps_deploy.sh`
- `agraz_backend/scripts/vps_setup.sh`

Those scripts assume `/opt/agraz` in places. Live server uses `/var/www/agraz_backend` — adapt paths if you ever re-run a full install.

---

## Phrase book for the agent

| You say | Agent does |
|---------|------------|
| `update the VPS` | Build + guide you through backend **and** admin upload/restart |
| `update backend` | Binary only |
| `update admin` | Admin SPA only |
| `rollback backend` | Restore `agraz_backend.bak` |




login details

nanunandi@gmail.com
NNNar@9886756
root password: 9MMGSHy7w(?A?rNfQ&Rq
ssh root@88.222.242.192
https://hpanel.hostinger.com/vps/1063810/overview
