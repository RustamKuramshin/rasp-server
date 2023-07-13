#!/bin/sh -e

erb -T - '/build/templates/ksql-server.properties.erb' \
    > '/etc/ksql/ksql-server.properties'
