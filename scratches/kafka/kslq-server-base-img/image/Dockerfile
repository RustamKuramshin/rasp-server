ARG BASEIMAGE
FROM $BASEIMAGE

RUN install_java 8u192

RUN curl -L https://packages.confluent.io/deb/5.3/archive.key | apt-key add - \
    && echo "deb [arch=amd64] https://packages.confluent.io/deb/5.3 stable main" >>/etc/apt/sources.list \
    && apt-get update && apt-get install -y confluent-ksql

COPY run_once /etc/my_init.d/
COPY run /etc/service/
COPY templates /build/templates
