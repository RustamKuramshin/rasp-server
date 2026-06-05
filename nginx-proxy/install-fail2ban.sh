#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGROTATE_PATH="/etc/logrotate.d/nginx-proxy"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -n "$0" "$@"
fi

install -d -m 755 /etc/fail2ban/filter.d /etc/fail2ban/action.d /etc/fail2ban/jail.d
install -m 644 "$PROJECT_DIR/fail2ban/filter.d/nginx-probe.conf" /etc/fail2ban/filter.d/nginx-probe.conf
install -m 644 "$PROJECT_DIR/fail2ban/action.d/docker-user-drop.conf" /etc/fail2ban/action.d/docker-user-drop.conf
install -m 644 "$PROJECT_DIR/fail2ban/jail.d/nginx-proxy.local" /etc/fail2ban/jail.d/nginx-proxy.local

if ! command -v fail2ban-server >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban
fi

cat > "$LOGROTATE_PATH" <<'EOF'
/home/ubuntu/rasp-server/nginx-proxy/data/nginx/logs/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
}
EOF

systemctl enable --now fail2ban
systemctl restart fail2ban

for _ in {1..20}; do
  if fail2ban-client ping >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

fail2ban-server -t
fail2ban-client status
