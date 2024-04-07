#!/bin/bash
set -euxo pipefail

# ── System setup ──────────────────────────────────────────────────────────────
dnf update -y
dnf install -y docker git

systemctl enable --now docker

# ── Docker Compose v2 plugin ──────────────────────────────────────────────────
COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)

mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# ── Clone CTFd ────────────────────────────────────────────────────────────────
git clone https://github.com/CTFd/CTFd.git /opt/ctfd
cd /opt/ctfd

# ── Inject SECRET_KEY via Compose override (keeps upstream docker-compose.yml clean) ──
SECRET_KEY=$(head -c 64 /dev/urandom | base64 | tr -d '\n/+=' | head -c 64)

cat > /opt/ctfd/docker-compose.override.yml <<EOF
services:
  ctfd:
    environment:
      - SECRET_KEY=${SECRET_KEY}
EOF

# ── Start CTFd (app + MySQL + Redis) ─────────────────────────────────────────
# Add this to user_data.sh before docker compose up -d
mkdir -p /root/.docker/cli-plugins
curl -SL https://github.com/docker/buildx/releases/download/v0.17.0/buildx-v0.14.0.linux-amd64 \
  -o /root/.docker/cli-plugins/docker-buildx
chmod +x /root/.docker/cli-plugins/docker-buildx

docker compose up -d
