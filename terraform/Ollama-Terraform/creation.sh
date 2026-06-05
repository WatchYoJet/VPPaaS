#!/bin/bash
cd
sudo yum update -y

# Ollama
sudo curl -fsSL https://ollama.com/install.sh | sh
sudo sed -i "s/\[Install\]/Environment=\"OLLAMA_HOST=0.0.0.0:11434\"\n\[Install\]/g" /etc/systemd/system/ollama.service
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama

# Wait until Ollama is actually responding before pulling
until curl -s http://localhost:11434/ > /dev/null 2>&1; do sleep 2; done
# Pull via REST API so the model is stored under the Ollama service user, not root
curl -s -X POST http://localhost:11434/api/pull -d '{"name":"llama3.2","stream":false}'

# Docker for FlexibilityForecasting
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo docker login -u "watchyojet" -p "dckr_pat_Fi78bFUoqKyPyhyuibKbM5s6szU"
sudo docker pull watchyojet/flexibilityforecasting:1.0.0-SNAPSHOT
sudo docker run -d --name flexibilityforecasting --network=host -e FLEXIBILITYEVENT_SERVICE_URL="http://ec2-44-223-40-47.compute-1.amazonaws.com:8081" watchyojet/flexibilityforecasting:1.0.0-SNAPSHOT
