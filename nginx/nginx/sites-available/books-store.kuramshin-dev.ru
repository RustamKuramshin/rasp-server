server {

    root /var/www/books-store.kuramshin-dev.ru/html;
    index index.html index.htm index.nginx-debian.html;

    server_name books-store.kuramshin-dev.ru www.books-store.kuramshin-dev.ru;

    location / {
#       try_files $uri $uri/ =404;
      proxy_pass http://localhost:8090;
    }

    listen [::]:443 ssl; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/books-store.kuramshin-dev.ru/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/books-store.kuramshin-dev.ru/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot


}server {
    if ($host = www.books-store.kuramshin-dev.ru) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    if ($host = books-store.kuramshin-dev.ru) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    listen [::]:80;

    server_name books-store.kuramshin-dev.ru www.books-store.kuramshin-dev.ru;
    return 404; # managed by Certbot




}