#!/bin/bash
echo "Starting..."

kafka_brokers="${kafka_brokers}"

i=1
kafka=""
for host in $kafka_brokers  # Loop through each host in the kafka_brokers variable
do
  kafka+="$host:9092,"
  ((i++))
done

# Remove the last comma
kafka="$${kafka%,}"

sudo yum install -y docker
sudo service docker start
sudo docker login -u "${docker_username}" -p "${docker_password}"
sudo docker pull "${docker_username}"/"${module_name}":1.0.0-SNAPSHOT
sudo docker run -d\
  --name "${module_name}"\
  -p 8080:8080\
  -e QUARKUS_DATASOURCE_USERNAME="${db_username}" \
  -e QUARKUS_DATASOURCE_PASSWORD="${db_password}" \
  -e QUARKUS_DATASOURCE_REACTIVE_URL="mysql://${rds_address}:${rds_port}/${db_name}" \
  -e KAFKA_BOOTSTRAP_SERVERS="$kafka" \
   "${docker_username}"/"${module_name}":1.0.0-SNAPSHOT
echo "Finished."