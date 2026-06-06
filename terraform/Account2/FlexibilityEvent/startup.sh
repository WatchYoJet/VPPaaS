#!/bin/bash
sudo service docker start
sudo docker login -u "${docker_username}" -p "${docker_password}"

sudo docker pull "${docker_username}/flexibilityevent:1.0.0-SNAPSHOT"
sudo docker run -d --name flexibilityevent -p 8080:8080 \
  -e QUARKUS_DATASOURCE_USERNAME="${db_username}" \
  -e QUARKUS_DATASOURCE_PASSWORD="${db_password}" \
  -e QUARKUS_DATASOURCE_REACTIVE_URL="mysql://${rds_address}:${rds_port}/${db_name}" \
  -e KAFKA_BOOTSTRAP_SERVERS="${kafka_brokers}" \
  -e TELEMETRY_SERVICE_URL="${telemetry_url}" \
  "${docker_username}/flexibilityevent:1.0.0-SNAPSHOT"

echo "FlexibilityEvent deployed." >> /tmp/startup.log
