server {

        root /var/www/kuramshin-dev.ru/html;
        index index.html index.htm index.nginx-debian.html;

        server_name kuramshin-dev.ru www.kuramshin-dev.ru;

        location / {
                try_files $uri $uri/ =404;
        }
    
    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/kuramshin-dev.ru/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/kuramshin-dev.ru/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot


}
server {
    if ($host = www.kuramshin-dev.ru) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    if ($host = kuramshin-dev.ru) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


        listen 80;
        listen [::]:80;

        server_name kuramshin-dev.ru www.kuramshin-dev.ru;
    return 404; # managed by Certbot




}