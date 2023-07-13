#!/usr/bin/env bash

docker build -t mysqltutorial .
docker run -p 53306:3306 -e MYSQL_ROOT_PASSWORD=test --name mysqltutorial -v $(pwd)/data:/var/lib/mysql --restart always -d mysqltutorial