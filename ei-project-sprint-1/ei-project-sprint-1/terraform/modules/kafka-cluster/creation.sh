#!/bin/bash
echo "Starting..."
cd
sudo wget https://dlcdn.apache.org/zookeeper/zookeeper-3.9.3/apache-zookeeper-3.9.3-bin.tar.gz
sudo tar -zxf apache-zookeeper-3.9.3-bin.tar.gz
sudo mv apache-zookeeper-3.9.3-bin /usr/local/zookeeper
sudo mkdir -p /var/lib/zookeeper
echo "tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
maxClientCnxns=60
initLimit=10
syncLimit=5" > /usr/local/zookeeper/conf/zoo.cfg
sudo yum -y install java-17-amazon-corretto-devel.x86_64
echo ${idBroker+1} > /var/lib/zookeeper/myid

sudo wget https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
sudo tar -zxf kafka_2.13-3.9.0.tgz

sudo mv kafka_2.13-3.9.0 /usr/local/kafka
sudo mkdir /tmp/kafka-logs
address=`curl http://169.254.169.254/latest/meta-data/public-hostname`
sudo sed -i "/^#listeners=PLAINTEXT:\/\/:9092/ s|$|,PLAINTEXT://$address:9092|" /usr/local/kafka/config/server.properties
sudo sed -i "s/broker.id=0/broker.id=${idBroker+1}/g" /usr/local/kafka/config/server.properties
sudo sed -i "s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=${totalBrokers}/g" /usr/local/kafka/config/server.properties
sudo sed -i "s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=${totalBrokers}/g" /usr/local/kafka/config/server.properties
sudo sed -i "s/transaction.state.log.min.isr=1/transaction.state.log.min.isr=${totalBrokers}/g" /usr/local/kafka/config/server.properties
sudo sed -i "s/^num.partitions=1/num.partitions=${totalBrokers}/g" /usr/local/kafka/config/server.properties
echo "default.replication.factor=${totalBrokers}" >> /usr/local/kafka/config/server.properties

touch /tmp/user_data_complete

echo "Finished."