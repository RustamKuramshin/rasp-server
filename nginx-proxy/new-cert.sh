#!/usr/bin/env bash

docker-compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d transmission.kuramshin-dev.ru \
  --email kuramshin.py@yandex.ru --agree-tos --no-eff-email