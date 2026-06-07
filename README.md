# VPPaaS

Virtual Power Plant as a Service. Distributed energy resource management with Quarkus microservices, Kafka, Kong, and Camunda BPMN. Deployed on AWS across two accounts.

## Structure

```
VPPaaS/
├── microservices/
│   ├── Prosumer/
│   ├── UtilityOperator/
│   ├── Telemetry/
│   ├── AssetLink/
│   ├── FlexibilityEvent/
│   ├── EnergyAnalytics/
│   ├── GridBalancing/
│   └── FlexibilityForecasting/
├── terraform/
│   ├── Account1/          # RDS, Kafka, Kong, Camunda, Prosumer, UtilityOperator, Telemetry
│   └── Account2/          # Konga, Ollama, AssetLink, FlexibilityEvent, EnergyAnalytics, GridBalancing
├── BPMN/
│   └── forms/
├── tests/                 # Shell integration tests + BPMN deployment script
│   └── VPPaaSSimulator.jar
├── Build.sh               # Build + push Docker images
├── CreateAMI.sh           # Create base AMIs (one-time per session)
├── Deploy.sh              # Deploy everything
└── Undeploy.sh            # Tear down everything
```

## Credentials (gitignored)

**`access.sh`**: Account 1:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_DEFAULT_REGION=us-east-1
export DockerUsername=...
export DockerPassword=...
```

**`access2.sh`**: Account 2 (same format, different AWS keys).

SSH keys go in the project root: `labsuser.pem` (Account 1), `labsuser2.pem` (Account 2).

## Deploying

```bash
# 1. Build and push all microservices to Docker Hub
bash Build.sh

# 2. Create base AMIs (once per AWS session — saves AMI IDs to amis.env)
bash CreateAMI.sh

# 3. Deploy all infrastructure and services
bash Deploy.sh
```

`Deploy.sh` writes all EC2 addresses to `account1-addresses.env` and registers Kong routes at the end.

All services are proxied through Kong at `http://<kong>:8000/<ServiceName>`.

Camunda is at `http://<camunda>:8080` - Operate on `/operate`, Tasklist on `/tasklist`, login `demo`/`demo`.

## BPMN Processes

After deploying, push the BPMN processes and forms to Camunda:

```bash
bash tests/deploy-bpmns.sh
```

## Running Tests

Each microservice has JUnit tests under `microservices/<Service>/src/test/`. Run them with:

```bash
cd microservices/Prosumer && ./mvnw test
```

For the shell integration tests, read addresses from `account1-addresses.env`. Run in dependency order:

```bash
bash tests/prosumer.sh
bash tests/utilityoperator.sh
bash tests/gridzone.sh
bash tests/assetlink.sh
bash tests/telemetry.sh          # populates Kafka — run before analytics tests
bash tests/energyanalytics.sh
bash tests/flexibilityevent.sh
bash tests/gridbalancing.sh
bash tests/forecast.sh           # requires llama3.2 loaded in Ollama
```

Or run everything at once:

```bash
bash run_all_tests.sh
```

## Undeploying

```bash
bash Undeploy.sh
```

## After an AWS session expires

Update `access.sh` and `access2.sh`, run `CreateAMI.sh` again (new session = new AMI IDs), then `Deploy.sh`.
