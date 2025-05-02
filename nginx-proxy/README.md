### Добавление нового домена для приложения

- `cd rasp-server/nginx-proxy/`
- `docker-compose down certbot`
- Либо через терминал и nano, либо по SFTP начать редактирование файлов
- В `docker-compose.yml` для сервиса `certbot` закомментировать строки с `entrypoint` и `command`
- Запустить `certbot` с параметрами выпуска нового сертификата:
  ```shell
  docker-compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d <УКАЗАТЬ ДОМЕН и СУБДОМЕН, ДЛЯ КОТОРОГО ВЫПУСКАЕТСЯ СЕРТИФИКАТ> \
  --email kuramshin.py@yandex.ru --agree-tos --no-eff-email
  ```
- Проверить, что файлы сертификатов были созданы: `sudo tree`
- Добавить в `nginx-proxy/data/nginx/conf.d/default.conf` новый блок для проксирования:
  ```nginx configuration
  # HTTPS - <НОВЫЙ СУБДОМЕН>.javaboys.ru
  server {
  listen 443 ssl;
  server_name <НОВЫЙ СУБДОМЕН>.javaboys.ru;
  
      ssl_certificate /etc/letsencrypt/live/<НОВЫЙ СУБДОМЕН>.javaboys.ru/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/<НОВЫЙ СУБДОМЕН>.javaboys.ru/privkey.pem;
  
      location / {
          proxy_pass http://172.17.0.1:<НОВЫЙ ПОРТ>;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
      }
  }
  ```
- `docker-compose restart nginx`
- Вернуть `docker-compose.yml` в исходный вид
- `docker-compose up -d certbot`