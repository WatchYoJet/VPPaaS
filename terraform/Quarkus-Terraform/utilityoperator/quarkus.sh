#!/bin/bash
echo "Starting..."

sudo yum install -y docker

sudo service docker start




echo "Finished."
sudo docker login -u "$DockerUsername" -p "$DockerPassword"
sudo docker pull $DockerUsername/utilityoperator:1.0.0-SNAPSHOT
sudo docker run -d --name utilityoperator -p 8080:8080 $DockerUsername/utilityoperator:1.0.0-SNAPSHOT
