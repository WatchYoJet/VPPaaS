#!/bin/bash
set -e
echo "Starting Kafka installation..."
cd /home/ec2-user
sudo yum -y install java-17-amazon-corretto-devel.x86_64
sudo wget -q https://dlcdn.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz
sudo tar -zxf kafka_2.13-4.1.1.tgz
sudo chown -R ec2-user:ec2-user kafka_2.13-4.1.1
touch /tmp/user_data_complete
echo "Kafka binaries installed."
