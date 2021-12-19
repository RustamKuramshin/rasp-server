#!/usr/bin/env bash

DOMAIN="kuramshin-dev.ru"

sudo mkdir -p /var/www/$1.${DOMAIN}/html && \
sudo chown -R $USER:$USER /var/www/$1.${DOMAIN}/html && \
sudo chmod -R 755 /var/www/$1.${DOMAIN} && \

cat  > /var/www/$1.${DOMAIN}/html/index.html <<EOF
<html>
    <head>
        <title>Welcome to $1.${DOMAIN}!</title>
    </head>
    <body>
        <h1>Success!  The $1.${DOMAIN} server block is working!</h1>
    </body>
</html>
EOF

cat  > /etc/nginx/sites-available/$1.${DOMAIN} <<EOF
server {
        listen 80;
        listen [::]:80;

        root /var/www/$1.${DOMAIN}/html;
        index index.html index.htm index.nginx-debian.html;

        server_name $1.${DOMAIN} www.$1.${DOMAIN};

        location / {
          try_files \$uri \$uri/ =404;
        }
}
EOF

sudo ln -s /etc/nginx/sites-available/$1.${DOMAIN} /etc/nginx/sites-enabled/ && \
sudo nginx -t && \
sudo systemctl restart nginx && \
sudo certbot run -n --nginx --agree-tos --redirect -d $1.${DOMAIN} -d www.$1.${DOMAIN}

NGINX_TRY_FILES="try_files \$uri \$uri\/ =404;"
NGINX_COMMENT_TRY_FILES_AND_PROXY_PASS="#try_files \$uri \$uri\/ =404;\n          proxy_pass http:\/\/localhost:$2;"
sed -i "s/${NGINX_TRY_FILES}/${NGINX_COMMENT_TRY_FILES_AND_PROXY_PASS}/g" ./$1.${DOMAIN}

sudo nginx -t && \
sudo systemctl restart nginx