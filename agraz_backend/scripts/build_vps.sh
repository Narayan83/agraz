#!/usr/bin/env bash
# Build a static Linux binary for VPS (amd64). Run from repo root or scripts/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT_DIR="$ROOT/release"
BINARY="$OUT_DIR/agraz-backend-linux-amd64"
VERSION="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"

mkdir -p "$OUT_DIR"

echo "Building agraz-backend for linux/amd64 (version $VERSION)..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -trimpath \
  -ldflags="-s -w" \
  -o "$BINARY" \
  .

echo "Done: $BINARY"
ls -lh "$BINARY"
file "$BINARY"

DEPLOY="$OUT_DIR/deploy"
mkdir -p "$DEPLOY/uploads"
cp "$ROOT/deploy/agraz-backend.service" "$DEPLOY/"
cp "$ROOT/.env.example" "$DEPLOY/.env.example"

cat > "$DEPLOY/README.txt" <<'EOF'
VPS deploy (Linux amd64)
========================
Preferred: run scripts/package_vps_deploy.sh locally, upload release/vps-bundle/
to /root/vps-bundle on the VPS, then: sudo bash vps_setup.sh

Manual copy:
  agraz-backend-linux-amd64 -> /opt/agraz/agraz_backend
  .env.example              -> /opt/agraz/.env (edit values)
  uploads/                  -> /opt/agraz/uploads/
EOF

tar -czf "$OUT_DIR/agraz-backend-vps-${VERSION}.tar.gz" -C "$OUT_DIR" \
  agraz-backend-linux-amd64 deploy

echo "Archive: $OUT_DIR/agraz-backend-vps-${VERSION}.tar.gz"
