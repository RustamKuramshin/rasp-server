#!/usr/bin/env bash

sudo mkdir -p /var/www/$1/html && \
sudo chown -R $USER:$USER /var/www/$1/html && \
sudo chmod -R 755 /var/www/$1 && \

cat  > /var/www/$1/html/index.html <<EOF
<html>
    <head>
        <title>Welcome to $1!</title>
    </head>
    <body>
        <h1>Success!  The $1 server block is working!</h1>
    </body>
</html>
EOF

cat  > /etc/nginx/sites-available/$1 <<EOF
server {
        listen 80;
        listen [::]:80;

        root /var/www/$1/html;
        index index.html index.htm index.nginx-debian.html;

        server_name $1 www.$1;

        location / {
                try_files $uri $uri/ =404;
        }
}
EOF

sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/ && \
sudo nginx -t && \
sudo systemctl restart nginx && \
sudo certbot --nginx -d $1 -d www.$1

NGINX_TRY_FILES="try_files \$uri \$uri\/ =404;"
NGINX_PROXY_PASS="proxy_pass http:\/\/localhost:$2;"
sed -i "s/${NGINX_TRY_FILES}/${NGINX_PROXY_PASS}/g" /etc/nginx/sites-available/$1

sudo nginx -t && \
sudo systemctl restart nginx