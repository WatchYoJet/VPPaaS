#!/bin/bash
echo "Starting..."

sudo yum install -y docker

sudo service docker start


echo "Finished."
sudo docker login -u "$DockerUsername" -p "$DockerPassword"
sudo docker pull $DockerUsername/assetlink:1.0.0-SNAPSHOT
sudo docker run -d --name assetlink -p 8080:8080 $DockerUsername/assetlink:1.0.0-SNAPSHOT
