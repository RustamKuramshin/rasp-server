#!/usr/bin/env bash

sudo mkdir -p /var/www/tm.kuramshin-dev.ru/html

sudo chown -R $USER:$USER /var/www/tm.kuramshin-dev.ru/html

sudo chmod -R 755 /var/www/tm.kuramshin-dev.ru

cat  > /var/www/tm.kuramshin-dev.ru/html/index.html <<EOF
<html>
    <head>
        <title>Welcome to tm.kuramshin-dev.ru!</title>
    </head>
    <body>
        <h1>Success!  The tm.kuramshin-dev.ru server block is working!</h1>
    </body>
</html>
EOF

cat  > /etc/nginx/sites-available/tm.kuramshin-dev.ru <<EOF
server {
        listen 80;
        listen [::]:80;

        root /var/www/tm.kuramshin-dev.ru/html;
        index index.html index.htm index.nginx-debian.html;

        server_name tm.kuramshin-dev.ru www.tm.kuramshin-dev.ru;

        location / {
                try_files $uri $uri/ =404;
        }
}
EOF

sudo ln -s /etc/nginx/sites-available/tm.kuramshin-dev.ru /etc/nginx/sites-enabled/

sudo nginx -t

sudo systemctl restart nginx

sudo certbot --nginx -d tm.kuramshin-dev.ru -d www.tm.kuramshin-dev.ru