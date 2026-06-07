#!/bin/bash
set -e
echo "Configuring Kafka KRaft cluster node ${node_id}..."

cd /home/ec2-user/kafka_2.13-4.1.1

# Stop any existing instance and wipe old data so format succeeds on re-runs
bin/kafka-server-stop.sh 2>/dev/null || true
sleep 5
rm -rf /tmp/kraft-combined-logs

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

bin/kafka-storage.sh format -t ${cluster_uuid} -c config/server.properties
bin/kafka-server-start.sh -daemon config/server.properties

# Wait for all controller voters to be reachable on port 9093 before checking
# local readiness. Uses bash /dev/tcp (always available) instead of nc.
for voter_dns in $(echo "${controller_voters}" | tr ',' '\n' | sed 's/[0-9]*@//; s/:9093//'); do
  echo "Waiting for controller at $voter_dns:9093 ..."
  retries=0
  until timeout 3 bash -c "echo > /dev/tcp/$voter_dns/9093" 2>/dev/null; do
    sleep 5
    retries=$((retries + 1))
    if [ $retries -ge 60 ]; then
      echo "ERROR: $voter_dns:9093 not reachable after 5 minutes. Kafka log:"
      tail -50 /home/ec2-user/kafka_2.13-4.1.1/logs/server.log 2>/dev/null || true
      exit 1
    fi
  done
done

until bin/kafka-topics.sh --list --bootstrap-server localhost:9092 > /dev/null 2>&1; do
  echo "Waiting for Kafka node ${node_id} to start..."
  sleep 5
done

echo "Kafka node ${node_id} is ready."
