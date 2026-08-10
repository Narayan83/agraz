#!/usr/bin/env python3
"""Ensure operator login user exists on production DB."""
import os
import subprocess
import sys

try:
    import bcrypt
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "bcrypt", "-q"])
    import bcrypt

EMAIL = os.environ.get("OP_EMAIL", "nanunandi@gmail.com").strip()
PLAIN = os.environ.get("OP_PASSWORD", "").strip()
if not PLAIN:
    print("OP_PASSWORD env required")
    raise SystemExit(2)


def load_env(path="/var/www/agraz_backend/.env"):
    env = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k] = v.strip().strip('"').strip("'")
    return env


def parse_cs(cs: str):
    kv = {}
    for part in cs.replace(";", " ").split():
        if "=" in part:
            k, v = part.split("=", 1)
            kv[k] = v
    return kv


def main():
    env = load_env()
    kv = parse_cs(env["DB_CONNECTION_STRING"])
    penv = os.environ.copy()
    penv["PGPASSWORD"] = kv["password"]
    host = kv.get("host", "127.0.0.1")
    user = kv.get("user")
    db = kv.get("dbname")
    port = str(kv.get("port", "5432"))

    def psql(sql: str, tuples=True) -> str:
        cmd = [
            "psql",
            "-h",
            host,
            "-p",
            port,
            "-U",
            user,
            "-d",
            db,
            "-v",
            "ON_ERROR_STOP=1",
        ]
        if tuples:
            cmd += ["-t", "-A"]
        cmd += ["-c", sql]
        r = subprocess.run(cmd, env=penv, capture_output=True, text=True)
        if r.returncode != 0:
            print("SQLERR", r.stderr)
            raise SystemExit(1)
        lines = [x.strip() for x in r.stdout.splitlines() if x.strip()]
        # Ignore psql chatter like "INSERT 0 1"
        useful = [ln for ln in lines if not ln.upper().startswith(("INSERT", "UPDATE", "DELETE"))]
        return useful[-1] if useful else (lines[-1] if lines else "")

    def q(s: str) -> str:
        return s.replace("'", "''")

    hashed = bcrypt.hashpw(PLAIN.encode(), bcrypt.gensalt(rounds=10)).decode()
    exists = psql(
        f"SELECT id FROM users WHERE lower(email)=lower('{q(EMAIL)}') LIMIT 1;"
    )
    if exists:
        uid = exists
        psql(
            f"""
UPDATE users SET
  password='{q(hashed)}',
  plain_password='{q(PLAIN)}',
  active=true,
  approved=true,
  firstname=COALESCE(NULLIF(firstname,''),'Narayan'),
  lastname=COALESCE(NULLIF(lastname,''),'Nandi'),
  updated_at=NOW()
WHERE id={uid};
"""
        )
        print("user_updated", uid)
    else:
        uid = psql(
            f"""
INSERT INTO users (
  tenant_id, firstname, lastname, email, password, plain_password,
  active, approved, created_at, updated_at
) VALUES (
  1, 'Narayan', 'Nandi', '{q(EMAIL)}', '{q(hashed)}', '{q(PLAIN)}',
  true, true, NOW(), NOW()
) RETURNING id;
"""
        )
        print("user_created", uid)

    # Find Super Admin role (table/column names may vary slightly)
    role = ""
    for sql in [
        "SELECT id FROM roles WHERE role_name='Super Admin' LIMIT 1;",
        "SELECT id FROM roles WHERE name='Super Admin' LIMIT 1;",
    ]:
        try:
            role = psql(sql)
            if role:
                break
        except SystemExit:
            continue
    print("role", role or "NOT_FOUND")

    if role:
        # Discover mapping table
        tables = psql(
            "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename ILIKE '%role%';",
            tuples=True,
        )
        print("role_tables", tables.replace("\n", ","))
        mapped = False
        for table, cols in [
            ("user_role_mappings", "user_id, role_id"),
            ("user_roles", "user_id, role_id"),
            ("user_role", "user_id, role_id"),
        ]:
            try:
                exists_map = psql(
                    f"SELECT 1 FROM {table} WHERE user_id={uid} AND role_id={role} LIMIT 1;"
                )
                if not exists_map:
                    psql(f"INSERT INTO {table} ({cols}) VALUES ({uid}, {role});")
                    print("role_mapped_via", table)
                else:
                    print("role_already_mapped", table)
                mapped = True
                break
            except SystemExit:
                continue
        if not mapped:
            print("WARN: could not map Super Admin role")

    print(
        "verify",
        psql(
            f"SELECT id||'|'||email||'|'||active::text||'|'||approved::text FROM users WHERE id={uid};"
        ),
    )


if __name__ == "__main__":
    main()
