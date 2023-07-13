
#docker run --name nginx --restart always -v /home/rkuramshin/default.conf:/etc/nginx/conf.d/default.conf:ro -v /home/rkuramshin/htdocs:/var/www/virtual/htdocs -d -p 9090:9090 nginx

FROM nginx
ADD htdocs /usr/share/nginx/html
ADD default.conf /etc/nginx/conf.d/default.conf

EXPOSE 9090