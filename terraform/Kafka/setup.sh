#!/bin/bash
set -e
echo "Configuring Kafka KRaft cluster node ${node_id}..."

cd /home/ec2-user/kafka_2.13-4.1.1

# Write server.properties — all $${...} are substituted by Terraform templatefile before this runs
cat > config/server.properties << 'ENDOFCONFIG'
node.id=${node_id}
process.roles=broker,controller
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://${my_dns}:9092
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT
log.dirs=/tmp/kraft-combined-logs
num.partitions=3
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
controller.quorum.voters=${controller_voters}
log.retention.hours=168
log.segment.bytes=1073741824
ENDOFCONFIG

# Format storage with the cluster-wide shared UUID
bin/kafka-storage.sh format -t ${cluster_uuid} -c config/server.properties

# Start Kafka
bin/kafka-server-start.sh -daemon config/server.properties

# Wait until Kafka accepts connections
sleep 10
until bin/kafka-topics.sh --list --bootstrap-server localhost:9092 > /dev/null 2>&1; do
  echo "Waiting for Kafka node ${node_id} to start..."
  sleep 5
done

echo "Kafka node ${node_id} is ready."
