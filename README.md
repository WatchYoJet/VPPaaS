# VPPaaS — Virtual Power Plant as a Service

A cloud-native platform for managing distributed energy resources. Prosumers (energy producers + consumers) are linked to utility operators via asset links. Real-time telemetry flows through Kafka, triggering analytics, flexibility events, and AI-powered forecasts. Business processes are orchestrated via Camunda BPMN.

---

## Architecture Overview

The system runs across **two AWS Academy accounts** (9 EC2 instance limit per account). Each microservice runs in its own EC2 instance using a pre-baked Docker AMI.

### Account 1

| Component | Purpose | Port |
|---|---|---|
| RDS (MySQL) | Shared database for all microservices | 3306 |
| Kafka (×3) | Message broker cluster | 9092 |
| Kong | API Gateway (proxy + admin) | 8000 / 8001 |
| Camunda | BPMN process engine | 8080 / 8081 / 8082 |
| Prosumer | Prosumer CRUD | 8080 |
| UtilityOperator | Utility operator + grid zone CRUD | 8080 |
| Telemetry | Kafka consumer → stores IoT events | 8080 |

### Account 2

| Component | Purpose | Port |
|---|---|---|
| Konga | Kong admin UI | 1337 |
| Ollama + FlexibilityForecasting | LLM inference + AI forecast endpoint | 11434 / 8080 |
| AssetLink | Links prosumers to utility operators | 8080 |
| FlexibilityEvent | Triggers flexibility offers from telemetry | 8080 |
| EnergyAnalytics | Aggregates telemetry into energy metrics | 8080 |
| GridBalancing | Balancing recommendations per grid zone | 8080 |

All microservices are reachable via Kong at `http://<kong>:8000/<ServiceName>`.

### Kafka Topics

| Topic | Producer | Consumer |
|---|---|---|
| `<id>-<location>` | VPPaaSSimulator | Telemetry |
| `energy-discharged-by-zone` | EnergyAnalytics | GridBalancing |
| `flexibility-offers` | FlexibilityEvent | — |

---

## Project Structure

```
VPPaaS/
├── microservices/
│   ├── Prosumer/                  # Prosumer entity CRUD
│   ├── UtilityOperator/           # Utility operator + GridZone CRUD
│   ├── Telemetry/                 # Kafka consumer for IoT data
│   ├── AssetLink/                 # Links prosumers to operators
│   ├── FlexibilityEvent/          # Flexibility event trigger + Kafka producer
│   ├── EnergyAnalytics/           # Energy aggregation + Kafka producer
│   ├── GridBalancing/             # Balancing recommendations (REST + Kafka consumer)
│   └── FlexibilityForecasting/    # AI forecast via Ollama (llama3.2)
├── terraform/
│   ├── Account1/
│   │   ├── RDS/                   # MySQL managed instance
│   │   ├── Kafka/                 # 3-node KRaft Kafka cluster
│   │   ├── Kong/                  # Kong API gateway
│   │   ├── Camunda/               # Camunda 8 process engine
│   │   ├── Prosumer/
│   │   ├── UtilityOperator/
│   │   └── Telemetry/
│   └── Account2/
│       ├── Konga/
│       ├── Ollama/                # Ollama + FlexibilityForecasting
│       ├── AssetLink/
│       ├── FlexibilityEvent/
│       ├── EnergyAnalytics/
│       └── GridBalancing/
├── BPMN-Processes/                # Camunda BPMN definitions
├── tests/                         # Shell-based integration tests
├── Build.sh                       # Build + push all Docker images
├── CreateAMI.sh                   # Create pre-baked Docker AMIs (one-time)
├── Deploy.sh                      # Full infrastructure deployment
└── Undeploy.sh                    # Full infrastructure teardown
```

---

## Prerequisites

- AWS Academy credentials for two accounts
- Terraform ≥ 1.0
- Docker (for building images)
- Java 17+ and Maven (for building microservices)
- `curl`, `jq`, `java` (for running tests)

### Credential files (gitignored)

**`access.sh`** — Account 1 credentials:
```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_DEFAULT_REGION=us-east-1
export DockerUsername=your-dockerhub-username
export DockerPassword=your-dockerhub-token
```

**`access2.sh`** — Account 2 credentials (same format, different AWS keys; `DockerUsername`/`DockerPassword` are the same Docker Hub account).

**PEM keys** — place in `~/.ssh/`:
- `~/.ssh/labsuser.pem` — Account 1 SSH key
- `~/.ssh/labsuser2.pem` — Account 2 SSH key

---

## How to Run

### Step 1 — Build and push Docker images

Builds all microservices with the `prod` profile and pushes to Docker Hub.

```bash
bash Build.sh
```

This runs `./mvnw package -Dquarkus.profile=prod` for each service, which triggers `quarkus.container-image.push=true`.

### Step 2 — Create base AMIs (one-time per AWS session)

Launches a temporary EC2 in each account, installs Docker, creates an AMI snapshot, and saves the AMI IDs to `amis.env`. Subsequent deployments reuse these AMIs — no Docker install at boot time.

```bash
bash CreateAMI.sh
```

This produces `amis.env`:
```
ACCOUNT1_AMI=ami-xxxxxxxxxxxxxxxxx
ACCOUNT2_AMI=ami-xxxxxxxxxxxxxxxxx
```

### Step 3 — Deploy

Deploys all infrastructure sequentially across both accounts, wires service URLs between accounts, and registers all Kong routes.

```bash
bash Deploy.sh
```

What it does:
1. Account 1: RDS → Kafka → Kong → Camunda → Prosumer → UtilityOperator → Telemetry
2. Saves all Account 1 addresses to `account1-addresses.env`
3. Switches to Account 2 credentials
4. Account 2: Konga → AssetLink → FlexibilityEvent → Ollama → EnergyAnalytics → GridBalancing
5. Appends Account 2 addresses to `account1-addresses.env`
6. Waits for Kong to be ready, then registers all 8 service routes

At the end it prints the full address table:
```
Account 1:
  Prosumer:        http://<dns>:8080
  UtilityOperator: http://<dns>:8080
  Telemetry:       http://<dns>:8080
  Kong (proxy):    http://<dns>:8000
  Kong (admin):    http://<dns>:8001
  Camunda:         http://<dns>:8080
  ...

Account 2:
  Konga:           http://<dns>:1337
  Ollama:          http://<dns>:11434
  AssetLink:       http://<dns>:8080
  ...
```

### Step 4 — Undeploy

Destroys all infrastructure in reverse dependency order (Account 2 first, then Account 1).

```bash
bash Undeploy.sh
```

---

## Kong Routes

All services are accessible through Kong's proxy port (`:8000`):

| Path | Upstream |
|---|---|
| `/Prosumer` | Prosumer:8080 |
| `/UtilityOperator` | UtilityOperator:8080 |
| `/AssetLink` | AssetLink:8080 |
| `/Telemetry` | Telemetry:8080 |
| `/FlexibilityEvent` | FlexibilityEvent:8080 |
| `/GridBalancing` | GridBalancing:8080 |
| `/EnergyAnalytics` | EnergyAnalytics:8080 |
| `/FlexibilityForecasting` | Ollama instance:8080 |

Konga (Kong admin UI) is at `http://<konga>:1337` — connect it to `http://<kong>:8001`.

---

## BPMN Processes

Deployed to Camunda (Operate: `:8081`, Tasklist: `:8082`, login: `demo`/`demo`).

| Process | Description |
|---|---|
| Prosumer-Management | Full prosumer lifecycle (create / update / delete) with KYC user task |
| Prosumer-Creation | Create a prosumer via Kong |
| Prosumer-Deletion | Delete a prosumer via Kong |
| Utility-Operator-Management | Utility operator lifecycle |
| Utility-Operator-Creation | Create a utility operator |
| Utility-Operator-Deletion | Delete a utility operator |
| Asset-Link-Management | Asset link lifecycle |
| Asset-Link-Creation | Link prosumer to utility operator |
| Asset-Link-Deletion | Remove an asset link |
| Telemetry-Ingestion | Register a Kafka topic for telemetry ingestion |
| Energy-Analytics | Trigger energy analytics computation |
| Flexibility-Emission | Trigger flexibility event evaluation |
| Flexibility-Forecasting | Request AI-based flexibility forecast |
| Grid-Balancing-Recommendation | Request grid balancing recommendation |

BPMN processes reference Kong routes (e.g. `http://kong-ip:8000/Prosumer`). `bpmn_test.sh` patches the placeholder before deploying.

---

## Running Tests

Tests read addresses from `account1-addresses.env` (written by `Deploy.sh`). Run them in this order to satisfy data dependencies:

```bash
# Core entities
bash tests/prosumer.sh
bash tests/utilityoperator.sh
bash tests/gridzone.sh

# Relationships
bash tests/assetlink.sh

# Telemetry — feeds data into Kafka (needed by analytics tests)
bash tests/telemetry.sh

# Analytics and events (require telemetry data)
bash tests/energyanalytics.sh
bash tests/flexibilityevent.sh
bash tests/gridbalancing.sh

# AI forecast (Ollama may take 30–60 s to respond)
bash tests/forecast.sh

# Full BPMN end-to-end
bash tests/bpmn_test.sh
```

The telemetry test uses `tests/VPPaaSSimulator.jar` to produce Kafka messages. It requires Java on the local machine.

---

## Re-running After an AWS Session Expires

AWS Academy sessions expire after a few hours. To redeploy:

1. Update `access.sh` and `access2.sh` with new credentials
2. Run `bash CreateAMI.sh` (new session = new AMI IDs needed)
3. Run `bash Deploy.sh`
