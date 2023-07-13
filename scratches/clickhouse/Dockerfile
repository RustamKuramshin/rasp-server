# mkdir -p ~/clickhouse/data && docker build -t clickhouse . && docker run -d -v ~/clickhouse/data:/home/clickhouse/data -p 9123:8123 -p 9124:9000 --name clickhouse --restart always clickhouse
# cat /home/clickhouse/data/*.csv | clickhouse-client --database=staging_logs --query="INSERT INTO log FORMAT CSV";
FROM yandex/clickhouse-server:latest
COPY init.sql /docker-entrypoint-initdb.d/init.sql
