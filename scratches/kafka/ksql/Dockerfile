FROM ubuntu:18.04

RUN apt-get update && apt-get install -y wget gnupg2 openjdk-8-jdk ant \
    && wget -qO - https://packages.confluent.io/deb/5.3/archive.key | apt-key add - \
    && echo "deb [arch=amd64] https://packages.confluent.io/deb/5.3 stable main" >>/etc/apt/sources.list \
    && apt-get update && apt-get install -y confluent-ksql ca-certificates-java \
    && update-ca-certificates -f

#ENV KSQL_BOOTSTRAP_SERVERS 192.168.2.77:32760,192.168.2.77:32761,192.168.2.77:32762,192.168.2.77:32763
#RUN export KSQL_BOOTSTRAP_SERVERS
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME 

ADD ./ksql-server.properties /etc/ksql/ksql-server.properties

EXPOSE 8088

CMD ["/usr/bin/ksql-server-start","/etc/ksql/ksql-server.properties"]
