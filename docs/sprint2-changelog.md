# VPPaaS — Sprint 2 Changelog

Sprint 1 deadline: 10/5/2026 | Sprint 2 deadline: 7/6/2026

---

## Overview

Sprint 2 adds the orchestration and integration layer on top of the Sprint 1 microservices:
- **Camunda 8** BPMN processes orchestrate all business operations
- **Kong API Gateway** exposes all 8 microservices through a single entry point
- **End-to-end test** validates the full flow from BPMN → Kong → microservice → DB
- **GridBalancing** algorithm corrected and extended with professor's feedback
- **Infrastructure** reorganised into two AWS accounts with updated deployment automation

---

## 1. BPMN Processes

### 1.1 New files added

| File | Description |
|---|---|
| `BPMN-Processes/Prosumer-Management.bpmn` | Entry process: user chooses Create / Delete / Abort, routes to sub-process |
| `BPMN-Processes/Prosumer-Creation.bpmn` | KYC user task → `POST /Prosumer` via Kong |
| `BPMN-Processes/Prosumer-Deletion.bpmn` | Review user task → `DELETE /Prosumer/{id}` via Kong |
| `BPMN-Processes/Utility-Operator-Management.bpmn` | Same pattern for Utility Operator |
| `BPMN-Processes/Utility-Operator-Creation.bpmn` | Review task → `POST /UtilityOperator` |
| `BPMN-Processes/Utility-Operator-Deletion.bpmn` | Review task → `DELETE /UtilityOperator/{id}` |
| `BPMN-Processes/Asset-Link-Management.bpmn` | Business Validation task → `POST /AssetLink` |
| `BPMN-Processes/Asset-Link-Creation.bpmn` | Creates asset link + Kafka topic |
| `BPMN-Processes/Asset-Link-Deletion.bpmn` | Revokes asset link |
| `BPMN-Processes/Telemetry-Ingestion.bpmn` | `GET /Telemetry/Consume` |
| `BPMN-Processes/Flexibility-Emission.bpmn` | `POST /FlexibilityEvent/trigger` |
| `BPMN-Processes/Grid-Balancing-Recommendation.bpmn` | `POST /GridBalancing/recommend` |
| `BPMN-Processes/Energy-Analytics.bpmn` | `POST /EnergyAnalytics/compute` |
| `BPMN-Processes/Flexibility-Forecasting.bpmn` | Review task → `POST /FlexibilityForecasting/forecast` |

### 1.2 Technical details

- **Connector type**: `io.camunda:http-json:1` (REST Outbound Connector shipped with C8Run 8.8.9). All service tasks use this type — NOT the old `type="http"` which was silently ignored.
- **method and url** go in `<zeebe:ioMapping>` inputs, NOT in `<zeebe:taskHeaders>`.
- **Kong placeholder**: all URLs use `kong-ip` as a literal placeholder, substituted at deploy time with `sed "s|kong-ip|$KONG_ADDRESS|g"`.
- **User tasks** that need API completion use `<zeebe:userTask />` extension — this makes them native Zeebe tasks accessible via `/v2/user-tasks/search` without explicit assignment.
- **Sub-process pattern**: Management BPMNs call Creation/Deletion BPMNs via `<bpmn:callActivity>` with `propagateAllChildVariables="true"`.

---

## 2. Kong API Gateway

### 2.1 Route configuration (`terraform/KongTerraform/configure_routes.sh`)

New script that configures all 8 routes idempotently (deletes and recreates on each run):

| Kong Route | Backend service | Port |
|---|---|---|
| `/Prosumer` | Prosumer EC2 (Account 1) | 8080 |
| `/UtilityOperator` | UtilityOperator EC2 (Account 1) | 8080 |
| `/Telemetry` | Telemetry EC2 (Account 1) | 8080 |
| `/AssetLink` | AssetLink EC2 (Account 2) | 8080 |
| `/FlexibilityEvent` | FlexibilityEvent EC2 (Account 2) | 8080 |
| `/EnergyAnalytics` | EnergyAnalytics EC2 (Account 2) | 8080 |
| `/GridBalancing` | GridBalancing EC2 (Account 2) | 8080 |
| `/FlexibilityForecasting` | Ollama EC2 (Account 2) | 8080 |

**Critical settings**: `strip_path=false` (preserve the path prefix when forwarding) and uppercase paths matching JAX-RS `@Path` annotations exactly. `strip_path=true` (old) was causing 404s.

**Note**: `configure_routes.sh` is **not called automatically by `Deploy.sh`**. After deployment, run it manually:
```bash
KONG_ADMIN_URL=http://$KONG_DNS:8001 \
PROSUMER_URL=http://$PROSUMER_DNS:8080 \
... \
bash terraform/KongTerraform/configure_routes.sh
```

### 2.2 Kong internals

Kong 3.9.0.0 runs with a **Postgres 13 backend** (both in Docker on the same EC2, connected via `kong-net`). On startup (`terraform/Account1/Kong/deploy.sh`):
1. Starts `postgres:13` container
2. Runs `kong migrations bootstrap`
3. Starts `kong/kong-gateway:3.9.0.0`

Ports exposed: `:8000` (proxy), `:8001` (Admin API), `:8002` (Kong Manager UI).

Konga runs on its own EC2 in Account 2 at `:1337`.

---

## 3. Infrastructure Reorganisation

### 3.1 Dual-account, one-EC2-per-microservice structure

AWS Academy caps each account at 9 EC2 instances. The project now deploys 14 EC2 instances split across two accounts, with **each microservice on its own EC2**:

| Account | EC2 instances | Services |
|---|---|---|
| Account 1 (8 EC2 + 1 RDS) | kafka-1, kafka-2, kafka-3, kong, camunda, prosumer, utilityoperator, telemetry | Core infrastructure + entity microservices |
| Account 2 (6 EC2) | konga, ollama, assetlink, flexibilityevent, energyanalytics, gridbalancing | Dependent microservices + admin UI |

```
terraform/
├── Account1/
│   ├── RDS/
│   ├── Kafka/
│   ├── Kong/
│   ├── Camunda/
│   ├── Prosumer/
│   ├── UtilityOperator/
│   └── Telemetry/
└── Account2/
    ├── Konga/
    ├── Ollama/           (includes FlexibilityForecasting)
    ├── AssetLink/
    ├── FlexibilityEvent/
    ├── EnergyAnalytics/
    └── GridBalancing/
```

Each module contains `main.tf`, `startup.sh` (or `deploy.sh`), and `terraform.tfvars`. All microservice EC2s use `t3.small`. Services run on port **8080** (one Docker container per EC2), started via `startup.sh` which:
- Starts Docker, logs in to Docker Hub
- Pulls the image (`docker_username/service:1.0.0-SNAPSHOT`)
- Runs the container with all config injected as environment variables (RDS URL, Kafka brokers, upstream service URLs)

**Exception — Ollama EC2**: Ollama is installed natively (not Docker) via the official install script and runs on port **11434**. FlexibilityForecasting runs as a Docker container with `--network=host` so it can reach Ollama on `localhost:11434`.

### 3.2 No-rebuild container deployment (AMI snapshots)

Each deploy uses a pre-baked Docker AMI — Docker is installed once, snapshotted, and all EC2s boot from that snapshot. Startup scripts only run `docker pull` + `docker run` (no `yum install` on each deploy).

`CreateAMI.sh` automates the snapshot creation:
1. Launches a temp t3.small from the base Amazon Linux 2 AMI
2. SSHs in and runs `yum install docker && systemctl enable docker`
3. Creates an AMI snapshot via `aws ec2 create-image`
4. Terminates the temp instance
5. Saves AMI IDs to `amis.env` (gitignored, read by `Deploy.sh`)

Two snapshots are created — one per AWS account — since AMI IDs are account-scoped.

### 3.3 Secrets and credentials management

| Secret | Location | How used |
|---|---|---|
| AWS session credentials (Account 1) | `access.sh` (gitignored) | Sourced by `CreateAMI.sh`, `Deploy.sh`, `Undeploy.sh` |
| AWS session credentials (Account 2) | `access2.sh` (gitignored) | Sourced mid-script when switching to Account 2 |
| Docker Hub PAT | `access.sh` / `access2.sh` (`DockerUsername`, `DockerPassword`) | Passed as `-var` flags to `terraform apply` — never stored in `terraform.tfvars` |
| SSH key (Account 1) | `labsuser.pem` (gitignored, project root) | Used by Kafka SSH provisioner + `CreateAMI.sh` |
| SSH key (Account 2) | `labsuser2.pem` (gitignored, project root) | Used by `CreateAMI.sh` for Account 2 temp instance |
| AMI IDs | `amis.env` (gitignored, generated by `CreateAMI.sh`) | Sourced by `Deploy.sh` |

`terraform.tfvars` files contain only infrastructure placeholders (RDS endpoint, Kafka brokers, service URLs) — no secrets.

### 3.4 Deployment scripts

| Script | Description |
|---|---|
| `CreateAMI.sh` | Creates Docker base AMI for Account 1 then Account 2; saves IDs to `amis.env` |
| `Deploy.sh` | Sources `access.sh` → deploys Account 1; sources `access2.sh` → deploys Account 2 |
| `Undeploy.sh` | Sources `access2.sh` → destroys Account 2; sources `access.sh` → destroys Account 1 |
| `clean-all-projects.sh` | Removes `.terraform/` caches, `amis.env`, `account1-addresses.env`, Maven `target/` |
| `access.sh.example` | Template for Account 1 credentials |
| `access2.sh.example` | Template for Account 2 credentials |

**Full lifecycle:**
```
./CreateAMI.sh   # ~10 min total (5 min per account)
./Deploy.sh      # Account 1 then Account 2, prints all endpoint URLs on completion
./Undeploy.sh    # Account 2 first (dependency order), then Account 1
```

### 3.5 Deploy.sh highlights

- Runs `terraform apply` in dependency order: RDS → Kafka → Kong → Camunda → microservices
- After each module, reads live DNS via `terraform output -raw` and injects into subsequent `terraform.tfvars` using `sed`
- `account1-addresses.env` is written after Account 1 completes and read at the start of Account 2
- `DOCKER_VARS_A1` / `DOCKER_VARS_A2` arrays pass Docker credentials and the correct AMI ID per account
- Account 2 `Ollama` is deployed after `FlexibilityEvent` so its URL is known

---

## 4. GridBalancing Microservice — Algorithm Fix

### 4.1 Problem (Sprint 1)

The `POST /GridBalancing/recommend` endpoint only read **BATTERY** assets and treated `Current_Output` (positive = discharging) as "load". This was:
- Incomplete: ignored SOLAR generation and EV charging entirely
- Semantically wrong: battery discharging *reduces* grid load, not increases it
- Thresholds hardcoded (0.8 / 0.5 of maxCapacity)
- No per-zone safety threshold on the domain model
- No geographic awareness (any zone paired with any other zone)

### 4.2 Fix (Sprint 2)

**Correct net load formula** (all 3 asset types):

```
net_load(zone) = sum(EV Charging_Rate)         ← increases grid demand
               − sum(Battery Current_Output)    ← +ve = discharge = reduces demand
               − sum(Solar Current_Generation)  ← always reduces demand
```

Positive `net_load` → zone stressed (importing from external grid).  
Negative `net_load` → zone has local surplus (exporting to grid).

**Battery exclusion filter** (per spec "Balancing Logic"):
- SoC < 20% → battery excluded from calculation (unavailable for balancing)
- Status = OFFLINE / FAULT / MAINTENANCE → excluded

**Per-zone safety threshold** (professor feedback: "evolve the domain model"):
- New field `safetyThreshold` (Double kW) added to `GridZone` entity
- Zone is **stressed** if `net_load > safetyThreshold`
- Zone has **surplus** if `net_load < 0.5 × safetyThreshold`
- Falls back to `0.8 × maxCapacity` if `safetyThreshold` is null (backward compatible)

**Neighbour zone detection** (professor feedback: "consecutive postal codes = adjacent cells"):
- New field `postalCode` (String) added to `GridZone` entity
- Only zones whose first-4-digit postal codes differ by ≤ 1 are considered neighbours
- Falls back to allowing all pairings if either zone has no postal code

**Kafka event trigger**: `@Incoming("energy-discharged-by-zone")` — auto-triggers `runRecommendation()` when EnergyAnalytics publishes new aggregates to this Kafka topic. Added `quarkus-messaging-kafka` dependency to `pom.xml` (Quarkus 3.x name; the old `quarkus-smallrye-reactive-messaging-kafka` no longer exists in the BOM).

### 4.3 Files changed

| File | Change |
|---|---|
| `microservices/GridBalancing/src/main/java/org/acme/GridBalancingResource.java` | Complete algorithm rewrite |
| `microservices/GridBalancing/src/main/resources/application.properties` | Added `%prod` Kafka channel config + `%test.mp.messaging.incoming...enabled=false` |
| `microservices/GridBalancing/pom.xml` | Added `quarkus-messaging-kafka` dependency |
| `microservices/UtilityOperator/src/main/java/org/acme/GridZone.java` | Added `safetyThreshold` + `postalCode` fields; updated all queries, constructor, save/update |
| `microservices/UtilityOperator/src/main/java/org/acme/UtilityOperatorResource.java` | Schema DDL: added `safetyThreshold DOUBLE, postalCode TEXT` columns to GridZone table |
| `microservices/UtilityOperator/src/main/java/org/acme/GridZoneResource.java` | PUT endpoint updated to pass new fields |

---

## 5. Test Infrastructure

### 5.1 JUnit tests (9 classes across all microservices)

All microservices now have JUnit 5 / QuarkusTest test classes:

| Microservice | Test class | Key tests |
|---|---|---|
| Prosumer | `ProsumerResourceTest` | Full CRUD (create, read, update, delete) |
| UtilityOperator | `UtilityOperatorResourceTest` | UtilityOperator CRUD + GridZone CRUD |
| Telemetry | `TelemetryResourceTest` | GET all, GET by id |
| Telemetry | `TelemetrySimulatorTest` | Integration: publishes to live Kafka, verifies DB ingestion |
| AssetLink | `AssetLinkResourceTest` | CRUD |
| FlexibilityEvent | `FlexibilityEventResourceTest` | Trigger endpoint, list |
| EnergyAnalytics | `EnergyAnalyticsResourceTest` | Compute endpoint |
| GridBalancing | `GridBalancingResourceTest` | GET list, POST recommend |
| FlexibilityForecasting | `FlexibilityForecastingResourceTest` | Forecast endpoint |

### 5.2 Shell integration tests (`tests/`)

| Script | Description |
|---|---|
| `bpmn_test.sh` | NEW — end-to-end BPMN test (see section 5.3) |
| `run_all_tests.sh` | NEW — master runner: starts VPPaaSSimulator, runs all 8 microservice tests, prints summary |
| `get-addresses.sh` | NEW — extracts live EC2 DNS addresses from Terraform state files |
| `prosumer.sh` | CRUD tests against live Prosumer service via Kong |
| `utilityoperator.sh` | CRUD tests for UtilityOperator + GridZone |
| `gridzone.sh` | GridZone CRUD |
| `assetlink.sh` | AssetLink CRUD + Kafka topic creation |
| `telemetry.sh` | Consume endpoint + data verification |
| `flexibilityevent.sh` | Trigger + list |
| `energyanalytics.sh` | Compute + verify |
| `gridbalancing.sh` | Recommend endpoint |
| `forecast.sh` | Flexibility Forecasting via Ollama |

### 5.3 BPMN end-to-end test (`tests/bpmn_test.sh`)

Full automated test of the Camunda + Kong integration:

1. Reads Camunda and Kong addresses from Terraform state (or CLI args)
2. Deploys all BPMN files to Camunda with `kong-ip` substituted
3. Starts a `ProsumerManagement` process instance with test variables
4. Polls Zeebe v2 API for the KYC user task (up to 60 seconds)
5. Completes the user task with `approved=true`
6. Waits for the service task to call `POST /Prosumer` via Kong
7. Verifies the prosumer was created in the DB via `GET /Prosumer`

Key API notes discovered during testing:
- Camunda 8 REST API v2 requires `processDefinitionKey` as a **string** (64-bit long), not a JSON number
- User tasks with `<zeebe:userTask />` are searchable via `/v2/user-tasks/search` and completable without prior assignment
- C8Run 8.8.9 serves all UIs (Operate, Tasklist, Zeebe) on a single port **8080** — not separate ports

---

## 6. Camunda Setup

### 6.1 Version

C8Run 8.8.9 — unified single-process deployment running:
- Zeebe broker + REST API
- Operate (process monitoring)
- Tasklist (user task management)
- Elasticsearch (index storage)
- Connectors runtime (includes REST Outbound)

All served from port **8080** (not separate ports). Login: `demo` / `demo`.

### 6.2 BPMN deployment

BPMN files are deployed via:
```bash
curl -u demo:demo -X POST http://$CAMUNDA:8080/v2/deployments \
  -F "resources=@/tmp/process.bpmn"
```

The `kong-ip` placeholder is replaced before upload:
```bash
sed "s|kong-ip|$KONG_ADDRESS|g" BPMN-Processes/Prosumer-Creation.bpmn > /tmp/Prosumer-Creation.bpmn
```

---

## 7. Known Issues & Workarounds

| Issue | Status | Workaround / Notes |
|---|---|---|
| `Deploy.sh` does not call `configure_routes.sh` | Open | After deployment, manually run `configure_routes.sh` with the env vars from `account1-addresses.env` |
| `mvn clean package` fails for GridBalancing (DevServices needs Docker) | Open | Build with `mvn clean package -DskipTests` or ensure Docker daemon is running |
| Telemetry JUnit integration test (`TelemetrySimulatorTest`) | Needs re-run | All fixes in place (OUTSIDE:// strip, `auto.offset.reset=earliest`) |
| `CreateAMI.sh` requires `labsuser.pem` and `labsuser2.pem` in `~/.ssh/` before first run | Expected | Download from AWS Academy → AWS Details for each account |

---

## 8. Docker Images

All images pushed to Docker Hub (`watchyojet`) with `linux/amd64,linux/arm64` multi-platform build:

- `watchyojet/prosumer:1.0.0-SNAPSHOT`
- `watchyojet/utilityoperator:1.0.0-SNAPSHOT`
- `watchyojet/assetlink:1.0.0-SNAPSHOT`
- `watchyojet/telemetry:1.0.0-SNAPSHOT`
- `watchyojet/flexibilityevent:1.0.0-SNAPSHOT`
- `watchyojet/energyanalytics:1.0.0-SNAPSHOT`
- `watchyojet/gridbalancing:1.0.0-SNAPSHOT`
- `watchyojet/flexibilityforecasting:1.0.0-SNAPSHOT`
