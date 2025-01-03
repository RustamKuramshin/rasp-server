#!/usr/bin/env bash

sudo apt update
sudo apt install certbot

sudo certbot certonly --standalone -d pgadmin.kuramshin-dev.ru
sudo certbot certonly --standalone -d minio.kuramshin-dev.ru
sudo certbot certonly --standalone -d nakormi-crm.ru

sudo certbot delete

sudo certbot certificates