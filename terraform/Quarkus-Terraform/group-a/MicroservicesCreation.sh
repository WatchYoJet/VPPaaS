#!/bin/bash
sudo yum install -y docker
sudo service docker start
sudo docker login -u "${docker_username}" -p "${docker_password}"

# Prosumer — port 8080
sudo docker pull "${docker_username}/prosumer:1.0.0-SNAPSHOT"
sudo docker run -d --name prosumer -p 8080:8080 \
  -e QUARKUS_DATASOURCE_USERNAME="${db_username}" \
  -e QUARKUS_DATASOURCE_PASSWORD="${db_password}" \
  -e QUARKUS_DATASOURCE_REACTIVE_URL="mysql://${rds_address}:${rds_port}/${db_name}" \
  "${docker_username}/prosumer:1.0.0-SNAPSHOT"

# UtilityOperator — port 8081
sudo docker pull "${docker_username}/utilityoperator:1.0.0-SNAPSHOT"
sudo docker run -d --name utilityoperator -p 8081:8080 \
  -e QUARKUS_DATASOURCE_USERNAME="${db_username}" \
  -e QUARKUS_DATASOURCE_PASSWORD="${db_password}" \
  -e QUARKUS_DATASOURCE_REACTIVE_URL="mysql://${rds_address}:${rds_port}/${db_name}" \
  "${docker_username}/utilityoperator:1.0.0-SNAPSHOT"

# Telemetry — port 8082
sudo docker pull "${docker_username}/telemetry:1.0.0-SNAPSHOT"
sudo docker run -d --name telemetry -p 8082:8080 \
  -e QUARKUS_DATASOURCE_USERNAME="${db_username}" \
  -e QUARKUS_DATASOURCE_PASSWORD="${db_password}" \
  -e QUARKUS_DATASOURCE_REACTIVE_URL="mysql://${rds_address}:${rds_port}/${db_name}" \
  -e KAFKA_BOOTSTRAP_SERVERS="${kafka_brokers}" \
  "${docker_username}/telemetry:1.0.0-SNAPSHOT"

echo "Group A deployed."
