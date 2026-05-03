#!/bin/bash
echo "Starting..."

sudo yum install -y docker

sudo service docker start




echo "Finished."
sudo docker login -u "watchyojet" -p "dckr_pat_Fi78bFUoqKyPyhyuibKbM5s6szU"
sudo docker pull watchyojet/telemetry:1.0.0-SNAPSHOT
sudo docker run -d --name telemetry -p 8080:8080 watchyojet/telemetry:1.0.0-SNAPSHOT
