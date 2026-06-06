# IE Tutorial Guide — Full Transcript
# Source: Tutorial-IE-2026.pdf-v1.0 (180 pages)
# Course: Enterprise Integration 2026 — Instituto Superior Tecnico, Universidade de Lisboa

> The following tutorials describe, in detail, the expected technological implementation using examples.
> The target integration architecture is overviewed using ArchiMate models (Application and Technological layers).

## Table of Contents

| Tutorial | Pages | Topic |
|---|---|---|
| P1-Kafka-in-AWSAcademy-v4.0 | 2–20 | Deploying Kafka 4.X in Amazon AWS EC2 |
| P2-HyperAutomation-TERRAFORM-v1.4 | 21–55 | HyperAutomation using Terraform: Infrastructure as Code |
| P3-Kafka-Distributed-v2.0 | 56–60 | Distributed Kafka 4.X service |
| P4-Kafka-Streams-AWS-v1.2 | 61–73 | Kafka Streaming in AWS |
| P5-RDS-database-v1.2 | 74–79 | RDS Database |
| P6-Quarkus_v1.11 | 80–105 | Quarkus microservice framework |
| P7-BPMN-CAMUNDA-v2.0 | 106–153 | BPMN with Camunda 8 |
| P8-Lambda-AWS-v1.3 | 154–166 | Lambda AWS |
| P9-KONG-v0.9 | 167–180 | Kong API Gateway |

---

## P1 — Deploying Kafka 4.X service in Amazon AWS EC2

**Goal**: Show how to operate a remote Kafka 4.X service: installation, starting, accessing, testing, stopping and backup.

### A. Creating AWS Academy Account and Private Key

1. Create AWS Academy account using invitation email
2. Accept terms, access course → select "AWS Academy Learner Lab"
3. Click "Start Lab" — when indicator is green, click "AWS Details"
4. Store the returned key file (.pem for OpenSSH, .ppk for PuTTY)
5. Click "AWS" to access AWS Management Console
6. Navigate: Services → Compute (EC2)

### B. Creating and Launching an AWS EC2 Instance

Configuration:
- **AMI**: Amazon Linux 2023 AMI 2023.10.20260105.0 x86_64 HVM kernel-6.1
- **Architecture**: 64-bit (x86)
- **Instance type**: t3.small
- **Key Pair**: vockey
- **Security Group**: launch-Kafka
  - Custom TCP Rule: Port 9092, Source 0.0.0.0/::/0
  - SSH: Port 22, Source 0.0.0.0/::/0

### C. Access EC2 via PuTTY (Windows)

1. Install PuTTY, convert .pem → .ppk using PuTTYgen
2. Hostname: `ec2-user@<public_dns_name>`
3. Connection type: SSH, Port 22
4. Auth: browse to .ppk file
5. Install Java: `sudo yum install java-17-amazon-corretto-devel.x86_64`

### D. Access EC2 via SSH (Linux/macOS)

```bash
chmod u=rwx,g=,o= myKeyAWS.pem
ssh -i myKeyAWS.pem ec2-user@YOURIP
```

File transfer:
```bash
scp -i my-key-pair.pem /path/SampleFile.txt ec2-user@ec2-198-51-100-1.compute-1.amazonaws.com:~
```

### F. Installing Kafka Manually in AWS EC2

```bash
cd
wget https://dlcdn.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz
sudo yum update
sudo yum install java-17-amazon-corretto-devel.x86_64
tar -zxf kafka_2.13-4.1.1.tgz
cd kafka_2.13-4.1.1

# Generate Cluster UUID
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"

# Format Log Directories (standalone mode)
bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c config/server.properties

# Start Kafka
bin/kafka-server-start.sh config/server.properties&
```

### G. Testing Kafka Locally

```bash
# Create topic
sudo bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic test

# Describe topic
sudo bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic test

# Produce messages
sudo bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test

# Consume messages
sudo bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning
```

### H. Testing Kafka Remotely (External Access)

Edit `config/server.properties`:
```properties
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://:9093
advertised.listeners=PLAINTEXT://Your_Public_DNS_Name:9092,CONTROLLER://localhost:9093
```

**Note**: Public DNS name changes on every EC2 reboot — reconfiguration may be needed.

---

## P2 — HyperAutomation using Terraform: Infrastructure as Code

**Goal**: Use Terraform to create cloud environments using code instead of AWS UI.

### A. Terraform Installation

- URL: https://developer.hashicorp.com/terraform/downloads
- Tested with Terraform v1.14.3 on darwin_arm64

Cache directory (macOS/Linux) in `~/.zshrc`:
```bash
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p "$TF_PLUGIN_CACHE_DIR"
```

### B. Obtaining AWS Access Credentials

Access via AWS Academy Learner Lab → Details → Show → copy secretKey/accessKey/token

### C. Deploying a Single EC2 Instance

```hcl
terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 4.0" }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
  token      = "YOUR_TOKEN"
}

resource "aws_instance" "example" {
  ami           = "ami-07ff62358b87c7116"
  instance_type = "t3.small"
  tags = { Name = "terraform-example" }
}
```

Commands:
```bash
terraform init && terraform apply   # Deploy
terraform show                       # Verify
terraform destroy                    # Clean up
# Tip: use -auto-approve to skip confirmation
```

### D. Deploying EC2 + Uploading Files

Use `provisioner "file"` in the resource block:
```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = file("test.pem")
  host        = "${self.public_dns}"
}
provisioner "file" {
  source      = "kafka_2.13-4.1.1.tgz"
  destination = "/home/ec2-user/kafka_2.13-4.1.1.tgz"
}
```

### E. Sending Commands at Boot (user_data)

```hcl
resource "aws_instance" "exampleKAFKA" {
  ami                         = "ami-07ff62358b87c7116"
  instance_type               = "t3.small"
  user_data                   = "${file("creation.sh")}"
  user_data_replace_on_change = true
}
```

Example `creation.sh`:
```bash
#!/bin/bash
echo "Starting..."
cd
sudo yum -y install java-17-amazon-corretto-devel.x86_64
sudo wget https://dlcdn.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz
sudo tar -zxf kafka_2.13-4.1.1.tgz
cd kafka_2.13-4.1.1
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
sudo bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c config/server.properties
sudo bin/kafka-server-start.sh config/server.properties&
echo "Finished."
```

**Debug**: User_data logs at `/var/log/cloud-init-output.log`

### F. Change Kafka Listener via Terraform

Use EC2 metadata service to get dynamic DNS name:
```bash
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
dnsname=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname`
sudo sed -i "s/listeners=PLAINTEXT:\/\/:9092.../listeners=PLAINTEXT:\/\/0.0.0.0:9092,CONTROLLER:\/\/:9093/g" config/server.properties
sudo sed -i "s/advertised.listeners=.../advertised.listeners=PLAINTEXT:\/\/$dnsname:9092/g" config/server.properties
```

### G. Multi-Broker Kafka Cluster with Terraform

```hcl
variable "nBroker" {
  type    = number
  default = 4
}

resource "aws_instance" "exampleCluster" {
  count         = var.nBroker
  ami           = "ami-07ff62358b87c7116"
  instance_type = "t3.small"
  user_data = base64encode(templatefile("creation.sh", {
    idBroker     = "${count.index}"
    totalBrokers = var.nBroker
  }))
}

output "publicdnslist" {
  value = "${formatlist("%v", aws_instance.exampleCluster.*.public_dns)}"
}

locals {
  replica_directorys = ["r1eMpKZRROex80kgn4_2-g", "bWIe6tPFS3mKvq-W-_kgtQ", "Z57HkCAASdifFa-QWCdGWA", ...]
  quorum_voters = join(",", [
    for i, instance in aws_instance.exampleCluster :
    "${i + 1}@${instance.public_dns}:9093:${local.replica_directorys[i]}"
  ])
}
```

### H. Showing Terraform Dependencies

```bash
terraform graph -draw-cycles
# Copy output to https://dreampuf.github.io/GraphvizOnline
```

### I. Sharing Terraform State Between Resources (AWS S3)

Store state remotely in S3 so later Terraform scripts can read output values:
```hcl
terraform {
  backend "s3" {
    bucket     = "terraform-s3-2026-01-27"
    key        = "stage/data-stores/mysql/terraform.tfstate"
    region     = "us-east-1"
    access_key = "YOUR_ACCESS_KEY"
    secret_key = "YOUR_SECRET_KEY"
    token      = "YOUR_TOKEN"
  }
}
```

Read remote state in another terraform file:
```hcl
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-2026-01-27"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-east-1"
    ...
  }
}
# Use: data.terraform_remote_state.db.outputs.address
```

### J. Creating Lambda Function + API Gateway Trigger (S3)

Key resources in .tf file:
- `aws_s3_bucket` + `aws_s3_object` → store compiled JAR
- `aws_lambda_function` → handler = `"example.Hello::handleRequest"`, runtime = `"java11"`
- `aws_api_gateway_rest_api` + `aws_api_gateway_resource` + `aws_api_gateway_method`
- `aws_api_gateway_integration` with `type = "AWS_PROXY"`
- `aws_lambda_permission` to allow API Gateway to invoke Lambda

**Test**:
```bash
curl -i -H "Content-Type: Application/json" --data "@body.json" -X POST https://<URL>/test/helloworldpath
```

### K. Kong and Konga Deployed in AWS EC2 via Terraform

**Kong deploy.sh**:
```bash
sudo yum install -y docker
sudo service docker start
sudo docker network create kong-net

# PostgreSQL database
sudo docker run -d --name kong-database --network=kong-net \
  -p 5432:5432 -e "POSTGRES_USER=kong" -e "POSTGRES_DB=kong" \
  -e "POSTGRES_PASSWORD=kongpass" postgres:13

# Run migrations
sudo docker run --rm --network=kong-net \
  -e "KONG_DATABASE=postgres" -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PG_PASSWORD=kongpass" -e "KONG_PASSWORD=test" \
  kong/kong-gateway:3.9.0.0 kong migrations bootstrap

# Start Kong Gateway
sudo docker run -d --name kong-gateway --network=kong-net \
  -e "KONG_DATABASE=postgres" -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PG_USER=kong" -e "KONG_PG_PASSWORD=kongpass" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
  -e "KONG_ADMIN_GUI_URL=http://localhost:8002" \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 -p 8443:8443 \
  kong/kong-gateway:3.9.0.0
```

**Konga deploy.sh** (separate EC2):
```bash
sudo yum install -y docker
sudo service docker start
sudo docker pull pantsel/konga
sudo docker run -d --name konga -p 1337:1337 pantsel/konga
```

### L. Camunda 8 Engine Deployed in AWS EC2 via Terraform

Instance type: `t3.large` (requires more RAM)

**deploy-camunda8.sh**:
```bash
sudo yum -y install java-21-amazon-corretto-devel.x86_64
wget https://downloads.camunda.cloud/release/camunda/c8run/8.8.9/camunda8-run-8.8.9-linux-x86_64.tar.gz
sudo tar xvf camunda8-run-8.8.9-linux-x86_64.tar.gz
sudo rm camunda8-run-8.8.9-linux-x86_64.tar.gz
sudo chmod -R 777 c8run
sudo runuser -l ec2-user -c 'cd /c8run && ./start.sh'
```

### M. Quarkus Project Deployed in AWS EC2 via Terraform

**quarkus.sh** (Docker image must be pre-pushed to Docker Hub):
```bash
sudo yum install -y docker
sudo service docker start
sudo docker login -u "YOUR_DOCKER_USERNAME" -p "YOUR_DOCKER_PASSWORD"
sudo docker pull YOUR_DOCKER_USERNAME/tryout1:1.0.0-SNAPSHOT
sudo docker run -d --name tryout2 -p 9000:9000 YOUR_DOCKER_USERNAME/tryout1:1.0.0-SNAPSHOT
```

> **Note**: Docker images built for ARM architecture may not work on AMD (x86_64) machines. Choose AMI and instance type matching the image architecture.

### N. Ollama Deployed in AWS EC2 via Terraform

Instance: `t3.large` with `volume_size = 50` GB

**creation.sh**:
```bash
cd
sudo yum update -y
sudo curl -fsSL https://ollama.com/install.sh | sh
export HOME=$HOME:/usr/local/bin
sudo sed -i "s/\[Install\]/Environment=\"OLLAMA_HOST=0.0.0.0:11434\"\n\[Install\]/g" /etc/systemd/system/ollama.service
sudo systemctl enable ollama
sudo systemctl start ollama
ollama pull llama3.2:latest
```

**Useful commands**:
```bash
ollama list          # Show loaded models
ollama ps            # Show running processors

# Test via REST
curl http://<EC2_DNS>:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

---

## P3 — Distributed Kafka 4.X Service

**Goal**: Use Kafka in a cluster environment with multiple brokers.

### A. Broker List Definition

In a cluster, consumers and producers connect to ALL brokers:
```
ec2-98-93-201-109.compute-1.amazonaws.com:9092,ec2-100-53-139-166.compute-1.amazonaws.com:9092,...
```

### B–F. Topic Management Commands

```bash
# List topics
sudo bin/kafka-topics.sh --list --bootstrap-server <Broker_list>

# Create topic with partitions
sudo bin/kafka-topics.sh --create --bootstrap-server <Broker_list> --replication-factor 1 --partitions 8 --topic clicks

# Add partitions
sudo bin/kafka-topics.sh --alter --bootstrap-server <Broker_list> --partitions 10 --topic clicks

# Delete topic
sudo bin/kafka-topics.sh --delete --bootstrap-server <Broker_list> --topic clicks

# Describe topic (shows partition count, leaders, replicas)
bin/kafka-topics.sh --describe --bootstrap-server <Broker_list> --topic clicks
```

### G–K. Producer/Consumer Commands

```bash
# Produce
bin/kafka-console-producer.sh --bootstrap-server <Broker_list> --topic clicks

# Consume
bin/kafka-console-consumer.sh --bootstrap-server <Broker_list> --topic clicks --from-beginning

# List consumer groups
sudo bin/kafka-consumer-groups.sh --bootstrap-server <Broker_list> --list

# Describe consumer group
sudo bin/kafka-consumer-groups.sh --bootstrap-server <Broker_list> --describe --group console-consumer-28356

# Set group-id in Java
props.put("group.id", "group-id-teste");
```

### O. Creating N Brokers in Different EC2 VMs

Each broker's `config/server.properties`:
```properties
process.roles=broker,controller
node.id=1                           # unique per broker (1, 2, 3...)
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://EC2_instance0:9092
controller.quorum.bootstrap.servers=EC2instance0:9093,EC2instance1:9093,EC2instance2:9093
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=3
```

Format storage (with initial-controllers for KRaft cluster):
```bash
sudo bin/kafka-storage.sh format -t uuid_cluster -c config/server.properties \
  --initial-controllers 1@EC2instance0:9093:uuid_ctrl1,2@EC2instance1:9093:uuid_ctrl2,3@EC2instance2:9093:uuid_ctrl3
```

### P. Broker Failure Test

```bash
# Create topic with replication
sudo bin/kafka-topics.sh --create --bootstrap-server <Broker_list> --replication-factor 2 --partitions 4 --topic events

# Stop one broker and verify partitions re-elect new leaders
bin/kafka-topics.sh --describe --bootstrap-server <Broker_list> --topic events
# Messages continue flowing with remaining broker
```

---

## P4 — Kafka Streaming in AWS

**Goal**: Introduce stream processing using Kafka Streams API.

Three examples from "Kafka: the Definitive Guide" (O'Reilly):
1. **Word Count** — map/filter pattern and simple aggregates
2. **Stock Market Statistics** — window aggregations
3. **Click Stream Enrichment** — streaming joins

### A. Installing Git in AWS EC2

```bash
sudo yum install git
git --version  # git version 2.47.1
```

### B. Installing Maven in AWS EC2

```bash
sudo yum -y install java-17-amazon-corretto-devel.x86_64
# Then download and install Maven from https://maven.apache.org/download.cgi
```

---

## P5 — RDS Database

**Goal**: Create and connect to an AWS RDS MySQL instance via Terraform.

Key Terraform resource:
```hcl
resource "aws_db_instance" "example" {
  identifier_prefix  = "terraform-up-and-running"
  engine             = "mysql"
  allocated_storage  = 20
  instance_class     = "db.t4g.micro"
  skip_final_snapshot = true
  publicly_accessible = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
}
output "address" { value = aws_db_instance.example.address }
output "port"    { value = aws_db_instance.example.port }
```

Security group must allow port 3306 (MySQL) from 0.0.0.0/0.

---

## P6 — Quarkus Microservice Framework

**Goal**: Develop reactive microservices with Quarkus 3.x, build Docker images, and deploy to AWS.

### Key Quarkus Features

- Reactive programming model (Mutiny)
- Integrated Kafka (SmallRye Reactive Messaging)
- Integrated REST (RESTEasy Reactive/Jakarta REST)
- JDBC/Panache for MySQL
- Swagger UI auto-generated at `/q/swagger-ui/`
- Docker image build via `quarkus.container-image.*` properties

### application.properties Key Settings

```properties
# Database
quarkus.datasource.db-kind=mysql
quarkus.datasource.jdbc.url=jdbc:mysql://${RDS_ADDRESS}:3306/${DB_NAME}
quarkus.datasource.username=${DB_USER}
quarkus.datasource.password=${DB_PASS}
quarkus.hibernate-orm.database.generation=update

# Kafka
kafka.bootstrap.servers=${KAFKA_BROKERS}
mp.messaging.incoming.telemetry.connector=smallrye-kafka
mp.messaging.incoming.telemetry.topic=my-topic

# Container image (for deployment)
%prod.quarkus.container-image.build=true
%prod.quarkus.container-image.push=true
%prod.quarkus.container-image.group=<dockerhub-username>
%prod.quarkus.container-image.name=<image-name>
%prod.quarkus.container-image.docker.buildx.platform=linux/amd64,linux/arm64
```

### Build + Push Docker Image

```bash
./mvnw package -Dquarkus.profile=prod
# Image pushed automatically if push=true
```

### REST Endpoint Example (JAX-RS)

```java
@Path("Prosumer")
@ApplicationScoped
public class ProsumerResource {
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Prosumer> getAll() { ... }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    public Response create(Prosumer p) { ... }
}
```

---

## P7 — BPMN with Camunda 8

**Goal**: Design and execute BPMN 2.0 business processes using Camunda 8 (C8Run 8.8.9).

### Camunda 8 Architecture (C8Run)

Components started by `./start.sh`:
- **Zeebe** — BPMN workflow engine (REST API on port 8080)
- **Elasticsearch** — index for Operate/Tasklist data (port 9200, localhost only)
- **Operate** — monitor running/completed instances (UI via port 8080)
- **Tasklist** — manage human/user tasks (UI via port 8080)
- **Connectors** — outbound REST, Kafka, and other connectors (port 8086)

### Key Zeebe REST API Endpoints (v2)

```
POST /v2/deployments              — deploy BPMN resources
POST /v2/process-instances        — start a process instance
POST /v2/user-tasks/search        — search user tasks (requires <zeebe:userTask>)
POST /v2/user-tasks/{key}/completion — complete a user task
GET  /v2/process-instances/{key}  — get process instance details
```

### BPMN Service Task — HTTP REST Connector

For Camunda 8 with REST Outbound Connector, use `type="io.camunda:http-json:1"`:

```xml
<bpmn:serviceTask id="Task_Kong" name="Call Kong">
  <bpmn:extensionElements>
    <zeebe:taskDefinition type="io.camunda:http-json:1" />
    <zeebe:ioMapping>
      <zeebe:input source="= &quot;POST&quot;"                target="method" />
      <zeebe:input source="= &quot;http://kong:8000/Prosumer&quot;" target="url" />
      <zeebe:input source="= body"                             target="body" />
      <zeebe:output source="= response.body"                   target="result" />
    </zeebe:ioMapping>
  </bpmn:extensionElements>
</bpmn:serviceTask>
```

**Important**: Method and URL go in `ioMapping` inputs (NOT in `taskHeaders`).

### BPMN User Task — Zeebe User Task

For user tasks manageable via Zeebe REST API (not Tasklist v1 only), add `<zeebe:userTask />`:

```xml
<bpmn:userTask id="Task_KYC" name="Business Validation (KYC)">
  <bpmn:extensionElements>
    <zeebe:userTask />
  </bpmn:extensionElements>
  <bpmn:incoming>Flow_0</bpmn:incoming>
  <bpmn:outgoing>Flow_1</bpmn:outgoing>
</bpmn:userTask>
```

### BPMN Exclusive Gateway (Approval Pattern)

```xml
<bpmn:exclusiveGateway id="Gateway_Approval" name="Approved?">
  <bpmn:incoming>Flow_1</bpmn:incoming>
  <bpmn:outgoing>Flow_2_yes</bpmn:outgoing>
  <bpmn:outgoing>Flow_2_no</bpmn:outgoing>
</bpmn:exclusiveGateway>

<bpmn:sequenceFlow id="Flow_2_yes" name="Yes" sourceRef="Gateway_Approval" targetRef="Task_Kong">
  <bpmn:conditionExpression xsi:type="bpmn:tFormalExpression">= approved = true</bpmn:conditionExpression>
</bpmn:sequenceFlow>
<bpmn:sequenceFlow id="Flow_2_no" name="No" sourceRef="Gateway_Approval" targetRef="EndEvent_Rejected">
  <bpmn:conditionExpression xsi:type="bpmn:tFormalExpression">= approved = false</bpmn:conditionExpression>
</bpmn:sequenceFlow>
```

### Deploying BPMN via REST API

```bash
curl -u demo:demo \
  -X POST http://camunda-host:8080/v2/deployments \
  -F "resources=@MyProcess.bpmn"
```

### Starting a Process Instance

```bash
curl -u demo:demo \
  -X POST http://camunda-host:8080/v2/process-instances \
  -H "Content-Type: application/json" \
  -d '{
    "processDefinitionKey": "2251799813685379",
    "variables": {
      "body": { "name": "Test", "location": "Lisbon" }
    }
  }'
```

### Completing a User Task

```bash
# Find task
curl -u demo:demo \
  -X POST http://camunda-host:8080/v2/user-tasks/search \
  -H "Content-Type: application/json" \
  -d '{"filter":{"processInstanceKey":"2251799813696550"}}'

# Complete task
curl -u demo:demo \
  -X POST http://camunda-host:8080/v2/user-tasks/{userTaskKey}/completion \
  -H "Content-Type: application/json" \
  -d '{"variables":{"approved":true}}'
```

### Camunda Web UI Access

| Interface | URL | Credentials |
|---|---|---|
| Main (Operate + Tasklist) | `http://host:8080/` | demo / demo |
| Zeebe REST API | `http://host:8080/v2/...` | Basic Auth: demo/demo |

---

## P8 — Lambda AWS

**Goal**: Create Java-based AWS Lambda functions and expose them via API Gateway.

### Lambda Function (Java 11)

```java
public class Hello implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {
    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent input, Context context) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        response.setStatusCode(200);
        response.setBody("{\"message\":\"Hello!\"}");
        return response;
    }
}
```

### Terraform Deployment

1. Upload JAR to S3: `aws_s3_object`
2. Create Lambda: `aws_lambda_function` (runtime=`java11`, handler=`example.Hello::handleRequest`)
3. Create API Gateway: `aws_api_gateway_rest_api` + resource + method + integration
4. Grant permission: `aws_lambda_permission`

IAM Role ARN: find in AWS Console → IAM service, or use format:
```
arn:aws:iam::<YourAWSAccountId>:role/LabRole
```

---

## P9 — Kong API Gateway

**Goal**: Configure Kong as an API gateway in front of microservices.

### Kong Architecture

- **Proxy port**: 8000 (HTTP), 8443 (HTTPS) — receives client requests
- **Admin API**: 8001 (HTTP), 8444 (HTTPS) — configuration
- **Kong Manager GUI**: 8002 — visual admin UI (built into Kong Enterprise 3.9.0.0)
- **Konga**: separate open-source UI, port 1337

### Creating Services and Routes via Admin API

```bash
# Create a Service (upstream microservice)
curl -X POST http://kong-host:8001/services \
  --data name="prosumer-service" \
  --data url="http://microservice-host:8080"

# Create a Route for the Service
curl -X POST http://kong-host:8001/services/prosumer-service/routes \
  --data name="prosumer-route" \
  --data paths[]="/Prosumer" \
  --data strip_path=false
```

**Important**: `strip_path=false` preserves the path prefix when forwarding to the upstream service. If `strip_path=true`, Kong strips the route path before forwarding (e.g., `/Prosumer/1` → `/1` at backend).

### Path Casing

The route path must match the JAX-RS `@Path` annotation exactly (case-sensitive):
- `@Path("Prosumer")` → route path must be `/Prosumer` (uppercase P)
- `@Path("UtilityOperator")` → route path must be `/UtilityOperator`

### Test via Kong Gateway

```bash
# Call microservice through Kong
curl http://kong-host:8000/Prosumer
curl -X POST http://kong-host:8000/Prosumer -H "Content-Type: application/json" -d '{"name":"Test"}'
```

### Kong + Konga in Docker (Single EC2)

```bash
sudo docker network create kong-net

# PostgreSQL
sudo docker run -d --name kong-database --network=kong-net \
  -e POSTGRES_USER=kong -e POSTGRES_DB=kong -e POSTGRES_PASSWORD=kongpass postgres:13

# Migrations
sudo docker run --rm --network=kong-net \
  -e KONG_DATABASE=postgres -e KONG_PG_HOST=kong-database \
  -e KONG_PG_PASSWORD=kongpass -e KONG_PASSWORD=test \
  kong/kong-gateway:3.9.0.0 kong migrations bootstrap

# Kong Gateway
sudo docker run -d --name kong-gateway --network=kong-net \
  -e KONG_DATABASE=postgres -e KONG_PG_HOST=kong-database \
  -e KONG_PG_USER=kong -e KONG_PG_PASSWORD=kongpass \
  -e KONG_ADMIN_LISTEN="0.0.0.0:8001, 0.0.0.0:8444 ssl" \
  -e KONG_ADMIN_GUI_URL="http://localhost:8002" \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 -p 8443:8443 \
  kong/kong-gateway:3.9.0.0

# Konga (co-located, no extra EC2 needed)
sudo docker run -d --name konga --network=kong-net -p 1337:1337 pantsel/konga
```

### Konga First-Time Setup

1. Navigate to `http://kong-host:1337`
2. Create admin account on first visit
3. Add connection: Name=`kong`, Kong Admin URL=`http://kong-gateway:8001`
4. Activate the connection

---

## References

### Kafka
- Kafka 4.1.X documentation: https://kafka.apache.org/41/
- Connecting to EC2 via SSH: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html

### Terraform
- Terraform Up & Running (3rd edition, 2022): https://www.terraformupandrunning.com/
- Terraform downloads: https://developer.hashicorp.com/terraform/downloads
- Terraform AWS tutorials: https://developer.hashicorp.com/terraform/tutorials/aws-get-started
- Lambda + API Gateway tutorial: https://developer.hashicorp.com/terraform/tutorials/aws/lambda-api-gateway

### Ollama
- Ollama API docs: https://github.com/ollama/ollama/blob/main/docs/api.md
- Ollama FAQ: https://github.com/ollama/ollama/blob/main/docs/faq.md

### VPPaaS Event Producer Tool
- https://github.com/Enterprise-Integration-IST-2026/VPPaaS-EventProducer
