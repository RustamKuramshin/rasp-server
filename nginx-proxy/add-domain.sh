#!/bin/bash

# ./add-domain.sh grafana.kuramshin-dev.ru http://host.docker.internal:3000

DOMAIN=$1
PROXY_TARGET=$2

if [[ -z "$DOMAIN" || -z "$PROXY_TARGET" ]]; then
  echo "Usage: ./add-domain.sh <domain> <proxy_target>"
  echo "Example: ./add-domain.sh grafana.example.com http://host.docker.internal:3000"
  exit 1
fi

CONF_FILE="./data/nginx/conf.d/default.conf"
CHALLENGE_ROOT="/var/www/certbot"

# 1. Добавляем домен в HTTP-блок (если ещё не добавлен)
if ! grep -q "$DOMAIN" "$CONF_FILE"; then
  sed -i "/server_name/s/;/ $DOMAIN;/" "$CONF_FILE"
  echo "[INFO] Added $DOMAIN to HTTP block."
fi

# 2. Добавляем новый HTTPS server-блок
cat <<EOF >> "$CONF_FILE"

# HTTPS - $DOMAIN
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass $PROXY_TARGET;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \${http_upgrade};
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

echo "[INFO] Added HTTPS block for $DOMAIN"

# 3. Выпускаем сертификат
echo "[INFO] Requesting certificate via certbot..."
docker-compose run --rm certbot certonly --webroot \
  --webroot-path=$CHALLENGE_ROOT \
  -d $DOMAIN \
  --email your-email@example.com --agree-tos --no-eff-email

# 4. Перезапускаем nginx
echo "[INFO] Restarting nginx container..."
docker-compose restart nginx

echo "[DONE] Domain $DOMAIN is ready and live (if DNS is set properly)."
