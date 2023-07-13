create database if not exists staging_logs;

create table if not exists staging_logs.log
(
    `timestamp` DateTime,
    `logid`     LowCardinality(String),
    `severity`  String,
    `facility`  String,
    `hostname`  LowCardinality(String),
    `taskid`    LowCardinality(String),
    `appname`   LowCardinality(String),
    `message`   String,
    `log`       String
)
    ENGINE = MergeTree() PARTITION BY (logid, toStartOfDay(timestamp)) PRIMARY KEY (timestamp, logid)
    ORDER BY (timestamp, logid, facility)
    SETTINGS index_granularity = 8192, merge_with_ttl_timeout = 86400;
