#!/usr/bin/env bash

sudo apt update
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl status nginx
sudo systemctl enable nginx

sudo cat /etc/nginx/nginx.conf

sudo nginx -t
sudo systemctl reload nginx

sudo cat /var/log/nginx/access.log
sudo cat /var/log/nginx/error.log