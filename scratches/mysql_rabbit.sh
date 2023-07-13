mysql -u root -ptestpass -e "CREATE DATABASE agate_test DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
mysql -u root -ptestpass -e "GRANT ALL PRIVILEGES ON agate_test.* TO 'agate'@'%' IDENTIFIED BY 'jxwqxdEt96iOcJ';"

mysql -u app_agateroot -h alpha-agate-mysql-master.baza-winner.ru -pIyL2CHRSyK

./node_modules/.bin/istanbul cover ./node_modules/mocha/bin/_mocha server/test/UserTest.js -- -t 10000 -g restrictions

docker run -p 6380:6380 --restart=always --name wcrawler-redis -d -v $(pwd)/docker/redis/redis.conf:/usr/local/etc/redis/redis.conf redis redis-server /usr/local/etc/redis/redis.conf --appendonly yes

# bind 127.0.0.1
redis-cli -p 6380 CONFIG SET protected-mode no или в redis.conf protected-mode no

./node_modules/.bin/istanbul cover ./node_modules/mocha/bin/_mocha server/test/UserTest.js -- -t 10000 -g noss

docker run --name agate-mysql -e MYSQL_ROOT_PASSWORD=testpass -d mysql:5.6

// rabbitmq
docker run -p 5672:5672 -p 15672:15672 --env RABBITMQ_ERLANG_COOKIE=SWQOKODSQALRPCLNMEQG --env RABBITMQ_DEFAULT_USER=wcraw-user --env RABBITMQ_DEFAULT_PASS=wcraw --name wcraw-rabbitmq --restart always -d rabbitmq:3-management
