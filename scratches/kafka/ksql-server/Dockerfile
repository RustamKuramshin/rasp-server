FROM confluentinc/cp-ksql-server:5.3.1

# Kafka cluster
ENV KSQL_BOOTSTRAP_SERVERS staging-kafka-log-1.xstaging.tv:9092,staging-kafka-log-2.xstaging.tv:9092,staging-kafka-log-3.xstaging.tv:9092
# REST 
ENV KSQL_LISTENERS http://0.0.0.0:8088/
# Scaling
ENV KSQL_KSQL_SERVICE_ID ksql_service_

EXPOSE 8088
