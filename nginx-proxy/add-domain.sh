#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   ./add-domain.sh grafana.example.com http://172.17.0.1:3000
#
# The script:
#   1. Adds the domain to the HTTP ACME/redirect server block.
#   2. Reloads nginx so Let's Encrypt can reach /.well-known/acme-challenge/.
#   3. Requests or reuses the certificate through the certbot compose service.
#   4. Adds the HTTPS reverse-proxy block.
#   5. Tests and reloads nginx.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$PROJECT_DIR/data/nginx/conf.d/default.conf"
CHALLENGE_ROOT="/var/www/certbot"
EMAIL="${CERTBOT_EMAIL:-kuramshin.py@yandex.ru}"
PUBLIC_IP="${PUBLIC_IP:-80.80.99.170}"

DOMAIN="${1:-}"
PROXY_TARGET="${2:-}"

usage() {
  cat <<EOF
Usage: $0 <domain> <proxy_target>

Example:
  $0 grafana.kuramshin-dev.ru http://172.17.0.1:3000

Environment:
  CERTBOT_EMAIL=$EMAIL
  PUBLIC_IP=$PUBLIC_IP
EOF
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() {
  echo "[INFO] $*"
}

compose() {
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

validate_input() {
  [[ -n "$DOMAIN" && -n "$PROXY_TARGET" ]] || {
    usage
    exit 1
  }

  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || die "Invalid domain: $DOMAIN"
  [[ "$PROXY_TARGET" =~ ^https?://[^[:space:]]+$ ]] || die "Proxy target must start with http:// or https://"
  [[ -f "$CONF_FILE" ]] || die "Nginx config not found: $CONF_FILE"
}

cert_exists() {
  [[ -f "$PROJECT_DIR/certbot/conf/live/$DOMAIN/fullchain.pem" && -f "$PROJECT_DIR/certbot/conf/live/$DOMAIN/privkey.pem" ]]
}

server_block_exists() {
  awk '
    $0 ~ /server[[:space:]]*\{/ {
      in_block = 1
      has_443 = 0
      has_domain = 0
    }
    in_block && $0 ~ /listen[[:space:]]+443/ {
      has_443 = 1
    }
    in_block && $0 ~ /server_name/ {
      line = $0
      sub(/^[[:space:]]*server_name[[:space:]]+/, "", line)
      sub(/;[[:space:]]*$/, "", line)
      n = split(line, names, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (names[i] == domain) {
          has_domain = 1
        }
      }
    }
    in_block && $0 ~ /^}/ {
      if (has_443 && has_domain) {
        found = 1
      }
      in_block = 0
    }
    END { exit found ? 0 : 1 }
  ' domain="$DOMAIN" "$CONF_FILE"
}

add_domain_to_http_server() {
  if awk '
    $0 ~ /listen[[:space:]]+80[; ]/ { in_http = 1 }
    in_http && $0 ~ /server_name/ && $0 ~ domain { found = 1 }
    in_http && $0 ~ /^}/ { in_http = 0 }
    END { exit found ? 0 : 1 }
  ' domain="$DOMAIN" "$CONF_FILE"; then
    info "$DOMAIN is already present in the HTTP server_name list."
    return
  fi

  CONF_FILE="$CONF_FILE" DOMAIN="$DOMAIN" python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["CONF_FILE"])
domain = os.environ["DOMAIN"]
text = path.read_text()

pattern = re.compile(r"(server\s*\{(?:(?!^\}).)*?listen\s+80[; ][\s\S]*?server_name\s+)([^;]+)(;)", re.MULTILINE)
match = pattern.search(text)
if not match:
    raise SystemExit("Could not find the HTTP server_name line")

names = match.group(2).split()
if domain not in names:
    names.append(domain)
    text = text[:match.start(2)] + " ".join(names) + text[match.end(2):]
    path.write_text(text)
PY

  info "Added $DOMAIN to the HTTP ACME/redirect server."
}

append_https_block() {
  if server_block_exists; then
    info "HTTPS server block for $DOMAIN already exists; config was not duplicated."
    return
  fi

  cat >> "$CONF_FILE" <<EOF

# HTTPS - $DOMAIN
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    limit_req zone=botlimit burst=20 nodelay;
    include /etc/nginx/snippets/blocked-paths.conf;

    location / {
        proxy_pass $PROXY_TARGET;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

  info "Added HTTPS reverse-proxy block for $DOMAIN -> $PROXY_TARGET."
}

reload_nginx() {
  compose exec -T nginx nginx -t
  compose exec -T nginx nginx -s reload
}

warn_if_dns_looks_wrong() {
  local resolved_ips
  resolved_ips="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')"
  if [[ -z "$resolved_ips" ]]; then
    echo "[WARN] DNS lookup for $DOMAIN returned no IPv4 records on this server."
    return
  fi

  if [[ " $resolved_ips " != *" $PUBLIC_IP "* ]]; then
    echo "[WARN] $DOMAIN resolves to: $resolved_ips"
    echo "[WARN] Expected public IP: $PUBLIC_IP"
    echo "[WARN] Certbot may fail until DNS and MikroTik forwarding point here."
  fi
}

request_certificate() {
  if cert_exists; then
    info "Certificate for $DOMAIN already exists; certbot will keep it until renewal is due."
  fi

  compose run --rm -T --no-deps certbot certonly \
    --webroot \
    --webroot-path "$CHALLENGE_ROOT" \
    --cert-name "$DOMAIN" \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --keep-until-expiring \
    --non-interactive
}

main() {
  validate_input
  cd "$PROJECT_DIR"

  local backup
  backup="$CONF_FILE.$(date +%Y%m%d-%H%M%S).bak"
  cp "$CONF_FILE" "$backup"
  info "Backup created: $backup"

  add_domain_to_http_server
  reload_nginx
  warn_if_dns_looks_wrong
  request_certificate
  append_https_block
  reload_nginx

  info "Done. $DOMAIN is configured and nginx was reloaded."
}

main "$@"
