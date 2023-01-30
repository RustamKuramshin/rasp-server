server {

        root /var/www/jenkins.kuramshin-dev.ru/html;
        index index.html index.htm index.nginx-debian.html;

        server_name jenkins.kuramshin-dev.ru www.jenkins.kuramshin-dev.ru;

        location / {
          #try_files $uri $uri/ =404;
          proxy_pass http://localhost:8300;
        }

    listen [::]:443 ssl; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/jenkins.kuramshin-dev.ru/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/jenkins.kuramshin-dev.ru/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot


}
server {
    if ($host = www.jenkins.kuramshin-dev.ru) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    if ($host = jenkins.kuramshin-dev.ru) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


        listen 80;
        listen [::]:80;

        server_name jenkins.kuramshin-dev.ru www.jenkins.kuramshin-dev.ru;
    return 404; # managed by Certbot




}
