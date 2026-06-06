#!/bin/bash
sudo service docker start
sudo docker login -u "${docker_username}" -p "${docker_password}"

sudo docker run -d --name konga \
  -p 1337:1337 \
  -e "NODE_ENV=production" \
  -e "DB_ADAPTER=postgres" \
  pantsel/konga

echo "Konga deployed." >> /tmp/startup.log
