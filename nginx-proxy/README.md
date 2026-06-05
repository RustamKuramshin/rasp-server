# nginx-proxy

Reverse proxy для домашних сервисов. Публичный HTTP/HTTPS трафик приходит на
Orange Pi, nginx проксирует запросы в локальную сеть или Docker-сервисы, а
certbot выпускает и обновляет Let's Encrypt сертификаты через `webroot`
challenge.

## Сервисы

- `nginx` - единственный постоянно запущенный compose-сервис.
- `certbot` - инструментальный сервис. Он запускается скриптами через
  `docker-compose run --rm -T certbot ...`; `docker-compose.yml` больше не надо
  комментировать/раскомментировать для выпуска или обновления сертификатов.

## Первичная настройка на сервере

```sh
cd /home/ubuntu/rasp-server/nginx-proxy
docker-compose up -d nginx
./install-renew-timer.sh
```

Таймер systemd запускает обновление два раза в день:

```sh
./renew-certs.sh
```

Скрипт проверяет DNS, запускает `certbot renew` по каждому рабочему сертификату,
проверяет конфиг nginx и делает reload nginx.

Перед обновлением каждый домен из сертификата должен резолвиться в `PUBLIC_IP`
по умолчанию `80.80.99.170`. Сертификаты с DNS-проблемами пропускаются с
сообщением `SKIP`, чтобы они не блокировали обновление остальных доменов.

## Добавить новый домен

Перед запуском проверь, что DNS домена указывает на публичный IP, а MikroTik
пробрасывает порты `80` и `443` на этот сервер.

```sh
cd /home/ubuntu/rasp-server/nginx-proxy
./add-domain.sh grafana.kuramshin-dev.ru http://172.17.0.1:3000
```

Скрипт:

1. Добавляет домен в HTTP-блок для ACME challenge и редиректа.
2. Перезагружает nginx, чтобы `/.well-known/acme-challenge/` был доступен.
3. Выпускает Let's Encrypt сертификат.
4. Добавляет HTTPS reverse-proxy блок.
5. Проверяет конфиг и перезагружает nginx.

## Полезные команды

```sh
docker-compose ps
docker-compose logs --tail=100 nginx
./renew-certs.sh
docker-compose run --rm -T --no-deps certbot certificates
systemctl status nginx-proxy-certbot-renew.timer
journalctl -u nginx-proxy-certbot-renew.service -n 100 --no-pager
```

## Защита от сканеров

Nginx пишет access/error логи в `data/nginx/logs/`. Эти файлы не попадают в git,
но доступны fail2ban на хосте.

Установка или обновление fail2ban-конфигурации:

```sh
cd /home/ubuntu/rasp-server/nginx-proxy
./install-fail2ban.sh
```

Jail `nginx-probe` банит IP, которые перебирают типовые уязвимые пути вроде
`/.env`, `/.git/config`, `/wp-admin`, `/server-status`, `/v2/_catalog`,
`/SDK/webLanguage`, `PROPFIND`, `LEAKIX` и похожие probes. Бан применяется через
Docker `DOCKER-USER` chain, поэтому блокирует трафик до nginx-контейнера.
Порог: 3 probe-события за 6 часов, бан на 24 часа с увеличением срока при
повторных банах.

Полезные команды:

```sh
fail2ban-client status
fail2ban-client status nginx-probe
./fail2ban-report.sh
sudo ./analyze-nginx-probes.py
fail2ban-client set nginx-probe unbanip <ip>
iptables -S DOCKER-USER
```

По умолчанию `add-domain.sh` использует:

- `CERTBOT_EMAIL=kuramshin.py@yandex.ru`
- `PUBLIC_IP=80.80.99.170`

Можно переопределить на один запуск:

```sh
CERTBOT_EMAIL=admin@example.com PUBLIC_IP=1.2.3.4 ./add-domain.sh app.example.com http://172.17.0.1:8080
```
