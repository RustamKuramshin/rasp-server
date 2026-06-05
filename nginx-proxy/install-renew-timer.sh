#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_PATH="/etc/systemd/system/nginx-proxy-certbot-renew.service"
TIMER_PATH="/etc/systemd/system/nginx-proxy-certbot-renew.timer"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -n "$0" "$@"
fi

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Renew nginx-proxy Let's Encrypt certificates
Wants=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/renew-certs.sh
EOF

cat > "$TIMER_PATH" <<'EOF'
[Unit]
Description=Run nginx-proxy certificate renewal twice daily

[Timer]
OnCalendar=*-*-* 03,15:17:00
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now nginx-proxy-certbot-renew.timer
systemctl list-timers nginx-proxy-certbot-renew.timer --no-pager
