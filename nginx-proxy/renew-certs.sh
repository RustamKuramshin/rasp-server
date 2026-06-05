#!/usr/bin/env bash
set -Eeuo pipefail

# Runs Let's Encrypt renewal through the certbot compose service and reloads
# nginx after a successful certbot run. Safe to run from cron/systemd.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHALLENGE_ROOT="/var/www/certbot"
PUBLIC_IP="${PUBLIC_IP:-80.80.99.170}"

compose() {
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

openssl_cert_ext() {
  local cert_path="$1"

  if [[ -r "$cert_path" ]]; then
    openssl x509 -in "$cert_path" -noout -ext subjectAltName 2>/dev/null
    return
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo -n openssl x509 -in "$cert_path" -noout -ext subjectAltName 2>/dev/null
  fi
}

cert_domains() {
  local cert_name="$1"
  local renewal_file="$PROJECT_DIR/certbot/conf/renewal/$cert_name.conf"
  local cert_path="$PROJECT_DIR/certbot/conf/live/$cert_name/cert.pem"
  local domains

  domains="$(
    openssl_cert_ext "$cert_path" |
      tr ',' '\n' |
      sed -n 's/.*DNS://p' |
      sed 's/^[[:space:]]*//;s/[[:space:]]*$//' |
      sort -u
  )"

  if [[ -n "$domains" ]]; then
    printf '%s\n' "$domains"
    return
  fi

  awk '
    /^\[\[webroot_map\]\]/ { in_map = 1; next }
    in_map && /^[[:space:]]*$/ { next }
    in_map && /^\[/ { in_map = 0 }
    in_map && /^[^#].*=/ {
      sub(/[[:space:]]*=.*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print
    }
  ' "$renewal_file" 2>/dev/null | sort -u
}

domain_points_here() {
  local domain="$1"
  getent ahostsv4 "$domain" 2>/dev/null |
    awk -v expected="$PUBLIC_IP" '$1 == expected { found = 1 } END { exit found ? 0 : 1 }'
}

renew_cert() {
  local cert_name="$1"

  compose run --rm -T --no-deps certbot renew \
    --cert-name "$cert_name" \
    --webroot \
    --webroot-path "$CHALLENGE_ROOT" \
    --quiet
}

cd "$PROJECT_DIR"

echo "[INFO] $(date -Is) starting certbot renewal check"

shopt -s nullglob
renewal_files=("$PROJECT_DIR"/certbot/conf/renewal/*.conf)

if [[ ${#renewal_files[@]} -eq 0 ]]; then
  echo "[INFO] No renewal configs found."
else
  failed=0
  attempted=0
  skipped=0

  for renewal_file in "${renewal_files[@]}"; do
    cert_name="$(basename "$renewal_file" .conf)"
    mapfile -t domains < <(cert_domains "$cert_name")

    if [[ ${#domains[@]} -eq 0 ]]; then
      echo "[WARN] $cert_name: cannot detect certificate domains; skipping."
      skipped=$((skipped + 1))
      continue
    fi

    bad_domains=()
    for domain in "${domains[@]}"; do
      if ! domain_points_here "$domain"; then
        bad_domains+=("$domain")
      fi
    done

    if [[ ${#bad_domains[@]} -gt 0 ]]; then
      echo "[SKIP] $cert_name: DNS does not point to $PUBLIC_IP for: ${bad_domains[*]}"
      skipped=$((skipped + 1))
      continue
    fi

    echo "[INFO] $cert_name: renewal check"
    if renew_cert "$cert_name"; then
      attempted=$((attempted + 1))
    else
      echo "[ERROR] $cert_name: certbot renew failed"
      failed=$((failed + 1))
    fi
  done

  echo "[INFO] Renewal checks attempted=$attempted skipped=$skipped failed=$failed"
fi

echo "[INFO] $(date -Is) testing nginx config"
compose exec -T nginx nginx -t

echo "[INFO] $(date -Is) reloading nginx"
compose exec -T nginx nginx -s reload

echo "[INFO] $(date -Is) renewal check completed"

if [[ "${failed:-0}" -gt 0 ]]; then
  exit 1
fi
