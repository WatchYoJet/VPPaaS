#!/bin/bash
cd
sudo yum update -y

# Ollama
sudo curl -fsSL https://ollama.com/install.sh | sh
sudo sed -i "s/\[Install\]/Environment=\"OLLAMA_HOST=0.0.0.0:11434\"\n\[Install\]/g" /etc/systemd/system/ollama.service
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama
sleep 10
ollama pull llama3.2

# Docker for FlexibilityForecasting
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo docker login -u "watchyojet" -p "dckr_pat_Fi78bFUoqKyPyhyuibKbM5s6szU"
sudo docker pull watchyojet/flexibilityforecasting:1.0.0-SNAPSHOT
sudo docker run -d --name flexibilityforecasting --network=host watchyojet/flexibilityforecasting:1.0.0-SNAPSHOT
