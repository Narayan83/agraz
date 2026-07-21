#!/usr/bin/env bash
# Fix pgAdmin backup binary paths (Windows pgAdmin + WSL PostgreSQL 14).
set -euo pipefail

PGADMIN_DB="/mnt/c/Users/tss/AppData/Roaming/pgAdmin/pgadmin4.db"
PG_BIN='C:\\Program Files\\PostgreSQL\\17\\bin'

if [[ ! -f "/mnt/c/Program Files/PostgreSQL/17/bin/pg_dump.exe" ]]; then
  echo "ERROR: Install PostgreSQL 17 client tools on Windows first." >&2
  exit 1
fi

if [[ ! -f "$PGADMIN_DB" ]]; then
  echo "ERROR: pgAdmin DB not found at $PGADMIN_DB" >&2
  exit 1
fi

if powershell.exe -NoProfile -Command "Get-Process pgAdmin4 -ErrorAction SilentlyContinue" 2>/dev/null | grep -q pgAdmin4; then
  echo "Closing pgAdmin..."
  powershell.exe -NoProfile -Command "Get-Process pgAdmin4 -ErrorAction SilentlyContinue | Stop-Process -Force"
  sleep 2
fi

cp "$PGADMIN_DB" "${PGADMIN_DB}.backup_$(date +%Y%m%d_%H%M%S)"

python3 << PY
import json, sqlite3

db = "/mnt/c/Users/tss/AppData/Roaming/pgAdmin/pgadmin4.db"
bin_path = r"C:\Program Files\PostgreSQL\17\bin"

conn = sqlite3.connect(db)
cur = conn.cursor()
cur.execute(
    "SELECT value FROM user_preferences up "
    "JOIN preferences p ON p.id = up.pid WHERE p.name = 'pg_bin_dir'"
)
row = cur.fetchone()
if not row:
    raise SystemExit("pg_bin_dir preference not found")

data = json.loads(row[0])
for entry in data:
    entry["binaryPath"] = bin_path
    entry["isDefault"] = entry.get("version") == "140000"

cur.execute(
    "UPDATE user_preferences SET value = ? "
    "WHERE pid = (SELECT id FROM preferences WHERE name = 'pg_bin_dir')",
    (json.dumps(data),),
)
cur.execute("UPDATE server SET host = '127.0.0.1' WHERE host = 'localhost'")
conn.commit()
conn.close()
print("Updated pg_bin_dir ->", bin_path)
print("Set PostgreSQL 14 as default binary set (WSL server version)")
print("Set server host localhost -> 127.0.0.1")
PY

echo ""
echo "Open pgAdmin. Backup agraz with:"
echo "  Format: Plain"
echo "  Filename: C:\\Users\\tss\\Desktop\\agraz_backup.sql"
