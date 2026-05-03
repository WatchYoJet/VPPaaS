# VPPaaS – Implementation Guide

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Data Models](#3-data-models)
4. [Kafka Topics & Communication](#4-kafka-topics--communication)
5. [Microservices Reference](#5-microservices-reference)
6. [Infrastructure Setup](#6-infrastructure-setup)
7. [Implementation Order](#7-implementation-order)
8. [How to Implement Each Microservice](#8-how-to-implement-each-microservice)
9. [Testing](#9-testing)

---

## 1. Project Overview

**VPPaaS** (Virtual Power Plant as a Service) is a cloud-based system that aggregates distributed energy resources (solar panels, batteries, EV chargers) owned by **Prosumers**, connects them to **Utility Operators** via digital contracts called **Asset Links**, and provides real-time monitoring, flexibility management, and grid balancing services.

### Key Actors
| Actor | Role |
|---|---|
| **Prosumer** | Household/business that owns energy assets (battery, solar, EV charger) and registers in VPPaaS to monetize them |
| **Utility Operator** | Energy grid manager that registers Grid Zones and establishes asset links with prosumers |
| **Prosumer Asset (IoT)** | Physical device that sends telemetry events via Kafka |

### Sprint 1 Goal
Implement all 8 microservices with REST APIs, Kafka integration, and AWS deployment via Terraform. Camunda and Kong are **not** part of Sprint 1.

**Deadline: 10/05/2026**

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS (us-east-1)                              │
│                                                                     │
│  ┌──────────────┐   ┌──────────────────────────────────────────┐   │
│  │  Event       │   │           Kafka Cluster (3 brokers)      │   │
│  │  Producer    │──▶│  {AssetLinkID}-{UtilityOperatorID} x N   │   │
│  │  Tool (sim.) │   │  flexibility-offers                      │   │
│  └──────────────┘   │  grid-balancing-recommendation           │   │
│                     │  energy-discharged-by-zone               │   │
│                     │  generated-energy-by-prosumer            │   │
│                     │  consumed-energy-by-prosumer             │   │
│                     │  average-soc                             │   │
│                     └──────────┬──────────────────────────────┘   │
│                                │                                    │
│  ┌─────────────────────────────▼──────────────────────────────┐   │
│  │                    Microservices (EC2 t4g)                  │   │
│  │                                                             │   │
│  │  [Prosumer]  [UtilityOperator]  [AssetLink]  [Telemetry]   │   │
│  │  [FlexibilityEvent]  [GridBalancing]  [EnergyAnalytics]    │   │
│  │  [FlexibilityForecasting] ──▶ [Ollama EC2 t2.large]        │   │
│  └─────────────────────────────┬──────────────────────────────┘   │
│                                │                                    │
│                     ┌──────────▼──────────┐                        │
│                     │   MySQL RDS (shared) │                        │
│                     └─────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Integration Patterns Used
| Pattern | Services | Description |
|---|---|---|
| **Pattern 1** — REST + RDS | Prosumer, UtilityOperator | Simple CRUD, no Kafka |
| **Pattern 2** — REST + RDS + Kafka | AssetLink, Telemetry, FlexibilityEvent, GridBalancing, EnergyAnalytics | Reads/writes DB and publishes or consumes Kafka |
| **Pattern 3** — REST → external API | FlexibilityForecasting | Calls Ollama REST endpoint, no local DB |

---

## 3. Data Models

### Prosumer
```sql
-- Exact schema from professor's reference (table name: Prosumer, singular)
CREATE TABLE Prosumer (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  FiscalNumber BIGINT UNSIGNED,
  location     TEXT NOT NULL
);
```

### UtilityOperator
```sql
-- No GridCells table in Sprint 1 reference; grid_cell_id is stored as TEXT in Telemetry
CREATE TABLE UtilityOperator (
  id       SERIAL PRIMARY KEY,
  name     TEXT NOT NULL,
  location TEXT NOT NULL
);
```

### AssetLink
```sql
-- No status/kafkaTopic fields in Sprint 1 reference; topic creation is added separately
CREATE TABLE AssetLink (
  id                 SERIAL PRIMARY KEY,
  idProsumer         BIGINT UNSIGNED,
  idUtilityOperator  BIGINT UNSIGNED,
  CONSTRAINT UC_Loyal UNIQUE (idProsumer, idUtilityOperator)
);
```

### Telemetry
```sql
-- Flat table — all 3 asset types in one row; inapplicable fields are NULL
-- Column names match Java field names exactly (PascalCase/mixed)
CREATE TABLE Telemetry (
  id                 SERIAL PRIMARY KEY,
  timeStamp          DATETIME,
  asset_id           BIGINT UNSIGNED,
  asset_type         TEXT NOT NULL,
  grid_cell_id       TEXT NOT NULL,
  -- BATTERY fields
  State_of_Charge    FLOAT,
  Available_Energy   FLOAT,
  Current_Output     FLOAT,
  Max_Capacity       FLOAT,
  State_of_Health    FLOAT,
  Status             TEXT NOT NULL,
  -- SOLAR fields
  Current_Generation FLOAT,
  Daily_Total        FLOAT,
  Grid_Voltage       FLOAT,
  Frequency          FLOAT,
  -- EV_CHARGER fields
  Plug_Status        TEXT NOT NULL,
  Charging_Rate      FLOAT,
  Session_Energy     FLOAT,
  EV_SoC             FLOAT
);
```

### FlexibilityEvent
```sql
CREATE TABLE FlexibilityEvents (
  id             SERIAL PRIMARY KEY,
  assetLinkId    BIGINT UNSIGNED NOT NULL,
  gridCellId     TEXT NOT NULL,
  eventType      TEXT NOT NULL,    -- e.g. "SELL", "UNAVAILABLE", "DISCHARGE_INCENTIVE"
  reason         TEXT,
  incentiveValue DOUBLE,
  timestamp      DATETIME NOT NULL
);
```

### GridBalancingRecommendation
```sql
CREATE TABLE GridBalancingRecommendations (
  id                  SERIAL PRIMARY KEY,
  deficitZoneId       TEXT NOT NULL,
  surplusZoneId       TEXT NOT NULL,
  recommendedActionKw DOUBLE NOT NULL,
  timestamp           DATETIME NOT NULL
);
```

### EnergyAnalytics
```sql
CREATE TABLE EnergyAnalytics (
  id             SERIAL PRIMARY KEY,
  analyticsType  ENUM('DISCHARGED_BY_ZONE','GENERATED_BY_PROSUMER',
                      'CONSUMED_BY_PROSUMER','AVERAGE_SOC') NOT NULL,
  dimensionKey   TEXT NOT NULL,   -- zone ID, prosumer ID, etc.
  value          DOUBLE NOT NULL,
  timestamp      DATETIME NOT NULL
);
```

---

## 4. Kafka Topics & Communication

### Topic Map
| Topic Name | Format | Producer | Consumer |
|---|---|---|---|
| `{AssetLinkID}-{OperatorName}` | Telemetry JSON (polymorphic) | Event Producer Tool | Telemetry microservice |
| `flexibility-offers` | FlexibilityEvent JSON | FlexibilityEvent | (dashboards / Sprint 2) |
| `grid-balancing-recommendation` | Recommendation JSON | GridBalancing | (dashboards / Sprint 2) |
| `energy-discharged-by-zone` | Analytics JSON | EnergyAnalytics | (dashboards) |
| `generated-energy-by-prosumer` | Analytics JSON | EnergyAnalytics | (dashboards) |
| `consumed-energy-by-prosumer` | Analytics JSON | EnergyAnalytics | (dashboards) |
| `average-soc` | Analytics JSON | EnergyAnalytics | (dashboards) |

### Telemetry Payload Examples

**BATTERY:**
```json
{
  "timeStamp": "2026-05-01 10:00:00.000",
  "asset_type": "BATTERY",
  "asset_id": "BATT-001",
  "grid_cell_id": "LISBON-DT",
  "payload": {
    "soc_percent": 92.5,
    "energy_available_kwh": 13.9,
    "active_power_kw": -7.2,
    "max_discharge_power_kw": 10.0,
    "soh_percent": 95.0,
    "connection_status": "ONLINE"
  }
}
```

**SOLAR:**
```json
{
  "asset_type": "SOLAR",
  "asset_id": "PV-001",
  "grid_cell_id": "PORTO-IND",
  "payload": {
    "generation_kw": 4.2,
    "daily_yield_kwh": 18.5,
    "ac_voltage_v": 230.1,
    "grid_frequency_hz": 50.02
  }
}
```

**EV_CHARGER:**
```json
{
  "asset_type": "EV_CHARGER",
  "asset_id": "EV-001",
  "grid_cell_id": "LISBON-DT",
  "payload": {
    "connector_status": "CHARGING",
    "charging_power_kw": 7.4,
    "session_energy_kwh": 12.3,
    "ev_soc_percent": 65.0
  }
}
```

### How Services Communicate

```
Event Producer Tool
        │  publishes to {AssetLinkID}-{OperatorName}
        ▼
  [Telemetry] ──── stores in RDS ────────────────────────────────┐
        │                                                         │
        │  (same topic consumed by)                               │
        ▼                                                         │
  [FlexibilityEvent]                                             │
        │  applies rules:                                         │
        │  soc > 90% + high price  → SELL event                  │
        │  soc < 20%               → UNAVAILABLE                 │
        │  publishes to flexibility-offers                        │
        ▼                                                         │
   Kafka: flexibility-offers                                      │
                                                                  │
  [GridBalancing] ◄── queries Telemetry + AssetLink REST ◄───────┘
        │  if zone load > threshold → find surplus neighbour
        │  publishes to grid-balancing-recommendation
        ▼
   Kafka: grid-balancing-recommendation

  [EnergyAnalytics] ◄── queries Telemetry REST ◄────────────────┘
        │  aggregates by zone/prosumer
        │  publishes to 4 analytics topics
        ▼
   Kafka: energy-discharged-by-zone
          generated-energy-by-prosumer
          consumed-energy-by-prosumer
          average-soc

  [AssetLink] ──── on activation: creates Kafka topic via Admin API
                                  stores topic name in RDS

  [FlexibilityForecasting] ──── queries FlexibilityEvent REST
                           ──── POST to Ollama :11434/api/generate
                                prompt: analyze past events for success rate
```

---

## 5. Microservices Reference

### Prosumer
- **Pattern:** REST + RDS
- **Port:** 8080
- **Endpoints (from professor's reference):**
  - `GET    /Prosumer`
  - `POST   /Prosumer`                              — body: `{"name":"..","FiscalNumber":123,"location":"Lisbon"}`
  - `GET    /Prosumer/{id}`
  - `PUT    /Prosumer/{id}/{name}/{FiscalNumber}/{location}`
  - `DELETE /Prosumer/{id}`
- **DB table:** `Prosumer`
- **Source:** `microservices/prosumer/`

### UtilityOperator
- **Pattern:** REST + RDS
- **Port:** 8080
- **Endpoints (from professor's reference):**
  - `GET    /UtilityOperator`
  - `POST   /UtilityOperator`                       — body: `{"name":"..","location":"Lisbon"}`
  - `GET    /UtilityOperator/{id}`
  - `PUT    /UtilityOperator/{id}/{name}/{location}`
  - `DELETE /UtilityOperator/{id}`
- **DB table:** `UtilityOperator`
- **Source:** `microservices/utility-operator/`

### AssetLink
- **Pattern:** REST + RDS (+ Kafka topic creation — must be added)
- **Port:** 8080
- **Endpoints (from professor's reference):**
  - `GET    /AssetLink`
  - `POST   /AssetLink`                             — body: `{"idProsumer":1,"idUtilityOperator":1}`
  - `GET    /AssetLink/{id}`
  - `GET    /AssetLink/{idProsumer}/{idUtilityOperator}`
  - `PUT    /AssetLink/{id}/{idProsumer}/{idUtilityOperator}`
  - `DELETE /AssetLink/{id}`
- **TODO:** on POST → also create Kafka topic `{id}-{utilityOperatorName}` via AdminClient
- **DB table:** `AssetLink`
- **Source:** `microservices/asset-link/`

### Telemetry
- **Pattern:** Kafka consumer + RDS + REST (no write endpoints)
- **Port:** 8080
- **Endpoints (from professor's reference):**
  - `POST   /Telemetry/Consume`   — registers a topic to consume; body: `{"TopicName":"1-GridZoneNorth"}`
  - `GET    /Telemetry`
  - `GET    /Telemetry/{id}`
- **Kafka:** spawns a `DynamicTopicConsumer` thread per registered topic
- **Key logic:** consumer parses `asset_type`, sets non-applicable fields to null, inserts flat row
- **DB table:** `Telemetry`
- **Source:** `microservices/telemetry/`

### FlexibilityEvent
- **Pattern:** REST + RDS + Kafka producer
- **Port:** 8080
- **Endpoints:**
  - `GET    /FlexibilityEvent`
  - `GET    /FlexibilityEvent/{id}`
  - `POST   /FlexibilityEvent/analyse`  — trigger analysis of latest telemetry
- **Kafka:** publishes to `flexibility-offers`
- **Rules:**
  - `soc_percent > 90` AND market hours → emit SELL event
  - `soc_percent < 20` → emit UNAVAILABLE event
  - Grid frequency `< 49.8 Hz` → emit EMERGENCY_DISCHARGE event
  - AC voltage `> 253 V` → emit OVERVOLTAGE_WARNING
- **DB table:** `FlexibilityEvents`

### GridBalancing
- **Pattern:** REST + RDS + Kafka producer
- **Port:** 8080
- **Endpoints:**
  - `GET    /GridBalancing`
  - `GET    /GridBalancing/{id}`
  - `POST   /GridBalancing/analyse`     — trigger cross-zone analysis
- **Kafka:** publishes to `grid-balancing-recommendation`
- **Logic:** query Telemetry for average SoC per zone → if zone load > 80% of maxCapacityKW, find a neighbour zone with SoC surplus → emit recommendation
- **DB table:** `GridBalancingRecommendations`

### EnergyAnalytics
- **Pattern:** REST + RDS + Kafka producer (4 topics)
- **Port:** 8080
- **Endpoints:**
  - `GET    /EnergyAnalytics`
  - `GET    /EnergyAnalytics/{id}`
  - `POST   /EnergyAnalytics/compute`  — trigger aggregation
- **Kafka:** publishes to `energy-discharged-by-zone`, `generated-energy-by-prosumer`, `consumed-energy-by-prosumer`, `average-soc`
- **DB table:** `EnergyAnalytics`

### FlexibilityForecasting (AI)
- **Pattern:** REST → Ollama
- **Port:** 8080
- **Endpoints:**
  - `POST   /FlexibilityForecasting/analyse` — body: `{ "lookbackHours": 24 }`
  - `GET    /FlexibilityForecasting/latest`
- **Logic:** fetch past N hours of FlexibilityEvents from DB → build text summary → POST to Ollama → return LLM assessment
- **Ollama call:**
  ```
  POST http://{OLLAMA_ADDRESS}:11434/api/generate
  { "model": "llama3.2", "prompt": "...", "stream": false }
  ```
- **No local DB** — reads FlexibilityEvent table, stores result in memory or returns directly

---

## 6. Infrastructure Setup

### Prerequisites
- AWS Academy account with `vockey` key pair downloaded as `labsuser.pem`
- Terraform >= 1.0 installed
- Docker with buildx installed
- Docker Hub account

### Steps

**1. Create S3 bucket for Terraform state**
```
AWS Console → S3 → Create bucket
  Name:   terraform-s3-vppaas-2026
  Region: us-east-1
  Block all public access: ON
```

**2. Place AWS credentials**
```
.aws/credentials   (one level above terraform/)
```
Format:
```
[default]
aws_access_key_id     = ...
aws_secret_access_key = ...
aws_session_token     = ...
```

**3. Place SSH key**
```
labsuser.pem   (one level above terraform/)
```

**4. Fill terraform.tfvars**
```
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```
Edit with your values:
```hcl
db_username               = "ie_project"
db_password               = "YourPassword123"
db_name                   = "vppaas"
nBroker                   = 3
docker_image_user         = "your-dockerhub-username"
docker_image_pull_token   = "your-dockerhub-read-token"
docker_image_create_token = "your-dockerhub-write-token"
```

**5. Deploy**
```bash
cd terraform
terraform init
terraform apply
```

Outputs you'll get (use these to configure microservices locally):
```
kafka_ips             = ["ec2-x.compute-1.amazonaws.com", ...]
rds_address           = "terraform-xxx.rds.amazonaws.com"
rds_port              = 3306
ollama_address        = ["ec2-y.compute-1.amazonaws.com"]
prosumerAddress       = "ec2-a.compute-1.amazonaws.com"
...
```

**6. Tear down**
```bash
terraform destroy
```

---

## 7. Implementation Order

```
Week 1
  Day 1 │ Terraform infra (Kafka + RDS + Ollama)   [DONE - terraform/ complete]
        │ Kafka topic design + sequence diagrams   [D1 deliverable]
  Day 2 │ Adapt Prosumer + UtilityOperator         [DONE - copied from professor's S3 reference]
        │ Update application.properties credentials
  Day 3 │ Adapt AssetLink                          [DONE - base copied, ADD Kafka topic creation on POST]
        │ Adapt Telemetry                          [DONE - base copied, verify pom.xml kafka dep]
  Day 4 │ FlexibilityEvent microservice
  Day 5 │ GridBalancing microservice
  Day 6 │ EnergyAnalytics microservice
        │ FlexibilityForecasting (Ollama) microservice
  Day 7 │ Integration testing end-to-end
  Day 8 │ Documentation + report
```

---

## 8. How to Implement Each Microservice

### Base: copy last year's project structure

Every microservice follows the same Quarkus skeleton. Copy from:
```
ei-project-sprint-1/microservices/customer/
```

Rename the folder and change these files:

**`pom.xml`** — change `<artifactId>` and `<name>`:
```xml
<artifactId>prosumer</artifactId>
<name>prosumer</name>
```

**`application.properties`** — standard config:
```properties
quarkus.datasource.db-kind=mysql
quarkus.datasource.username=${QUARKUS_DATASOURCE_USERNAME:ie_project}
quarkus.datasource.password=${QUARKUS_DATASOURCE_PASSWORD:password}
quarkus.datasource.reactive.url=${QUARKUS_DATASOURCE_REACTIVE_URL:mysql://localhost:3306/vppaas}

# For Kafka microservices, also add:
kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}

quarkus.container-image.build=true
quarkus.container-image.name=prosumer
quarkus.container-image.tag=1.0.0-SNAPSHOT
```

**`src/main/java/org/acme/`** — implement:
- `EntityName.java` — data model + static DB methods (findAll, findById, save, update, delete)
- `EntityNameResource.java` — JAX-RS REST endpoints

### Pattern for REST + RDS (Prosumer, UtilityOperator)

```java
@Path("Prosumer")
public class ProsumerResource {

    @Inject
    io.vertx.mutiny.mysqlclient.MySQLPool client;

    @Inject
    @ConfigProperty(name = "myapp.schema.create", defaultValue = "true")
    boolean schemaCreate;

    void config(@Observes StartupEvent ev) {
        if (schemaCreate) initdb();
    }

    private void initdb() {
        client.query("CREATE TABLE IF NOT EXISTS Prosumers (...)")
              .execute().await().indefinitely();
    }

    @GET
    public Multi<Prosumer> getAll() { return Prosumer.findAll(client); }

    @GET @Path("{id}")
    public Uni<Response> getOne(Long id) { ... }

    @POST
    public Uni<Response> create(Prosumer p) { ... }

    @PUT @Path("{id}")
    public Uni<Response> update(Long id, Prosumer p) { ... }

    @DELETE @Path("{id}")
    public Uni<Response> delete(Long id) { ... }
}
```

### Pattern for Kafka topic creation (AssetLink activate)

```java
// In AssetLinkResource.java
@Inject
@ConfigProperty(name = "kafka.bootstrap.servers")
String kafkaBrokers;

@PUT @Path("{id}/activate")
public Uni<Response> activate(Long id) {
    return AssetLink.findById(client, id)
        .onItem().transformToUni(link -> {
            String topicName = link.id + "-" + link.operatorName;
            createKafkaTopic(topicName);
            return AssetLink.setActive(client, id, topicName);
        })
        .onItem().transform(ok -> Response.ok().build());
}

private void createKafkaTopic(String topicName) {
    Properties props = new Properties();
    props.put("bootstrap.servers", kafkaBrokers);
    try (AdminClient admin = AdminClient.create(props)) {
        NewTopic topic = new NewTopic(topicName, 1, (short) 1);
        admin.createTopics(Collections.singleton(topic)).all().get();
    } catch (Exception e) {
        // topic may already exist — ignore TopicExistsException
    }
}
```

### Pattern for polymorphic Kafka consumer (Telemetry)

```java
// Extend DynamicTopicConsumer from last year — change the run() body:
public void run() {
    // ... same KafkaConsumer setup ...
    while (true) {
        ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
        for (ConsumerRecord<String, String> record : records) {
            JSONObject obj    = new JSONObject(record.value());
            String assetType  = obj.getString("asset_type");
            String assetId    = obj.getString("asset_id");
            String gridCellId = obj.getString("grid_cell_id");
            String timestamp  = obj.getString("timeStamp");
            JSONObject payload = obj.getJSONObject("payload");

            switch (assetType) {
                case "BATTERY"    -> insertBatteryTelemetry(assetId, gridCellId, timestamp, payload);
                case "SOLAR"      -> insertSolarTelemetry(assetId, gridCellId, timestamp, payload);
                case "EV_CHARGER" -> insertEvTelemetry(assetId, gridCellId, timestamp, payload);
            }
        }
        consumer.commitSync();
    }
}
```

### Pattern for Kafka producer (FlexibilityEvent, EnergyAnalytics)

```java
// In application.properties:
mp.messaging.outgoing.flexibility-offers.connector=smallrye-kafka
mp.messaging.outgoing.flexibility-offers.topic=flexibility-offers
mp.messaging.outgoing.flexibility-offers.value.serializer=org.apache.kafka.common.serialization.StringSerializer

// In Resource class:
@Channel("flexibility-offers")
Emitter<String> emitter;

// When emitting:
String message = "{\"eventType\":\"SELL\", \"assetLinkId\":" + id + ", ...}";
emitter.send(message);
```

### Pattern for Ollama call (FlexibilityForecasting)

```java
@ConfigProperty(name = "ollama.address")
String ollamaAddress;

public String analyse(String eventsText) {
    String prompt = "Analyse these VPP flexibility events and determine the success rate " +
                    "and sentiment: " + eventsText;
    String body = "{\"model\":\"llama3.2\",\"prompt\":\"" +
                  prompt.replace("\"","\\\"") + "\",\"stream\":false}";

    HttpRequest request = HttpRequest.newBuilder()
        .uri(URI.create("http://" + ollamaAddress + ":11434/api/generate"))
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString(body))
        .build();

    HttpResponse<String> response = HttpClient.newHttpClient()
        .send(request, HttpResponse.BodyHandlers.ofString());

    return new JSONObject(response.body()).getString("response");
}
```

---

## 9. Testing

### Test the Kafka cluster
```bash
# Create a test topic
kafka-topics.sh --create --topic test \
  --bootstrap-server {KAFKA_IP}:9092 --partitions 1 --replication-factor 1

# List topics
kafka-topics.sh --list --bootstrap-server {KAFKA_IP}:9092
```

### Run the Event Producer Tool
```bash
# Point it at your Kafka cluster and it will simulate telemetry
java -jar VPPaaS-EventProducer.jar \
  --bootstrap-servers {KAFKA_IP}:9092
```

### Test each microservice (curl examples)

**Create a Prosumer:**
```bash
curl -X POST http://{PROSUMER_IP}:8080/Prosumer \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","fiscalId":"PT123456789","address":"Rua A 1","postalCode":"1000-001"}'
```

**Create a UtilityOperator + GridCell:**
```bash
curl -X POST http://{UTILITY_IP}:8080/UtilityOperator \
  -d '{"name":"EDP","fiscalId":"PT500000000","address":"Av. B 2","postalCode":"1200-001"}'

curl -X POST http://{UTILITY_IP}:8080/GridCell \
  -d '{"operatorId":1,"name":"LISBON-DT","address":"Lisbon","postalCode":"1000","maxCapacityKW":50000}'
```

**Create and activate an AssetLink:**
```bash
curl -X POST http://{ASSETLINK_IP}:8080/AssetLink \
  -d '{"assetId":1,"gridCellId":1}'

curl -X PUT http://{ASSETLINK_IP}:8080/AssetLink/1/activate
# This creates Kafka topic "1-EDP" and the Event Producer can now send to it
```

**Register topic with Telemetry:**
```bash
curl -X POST http://{TELEMETRY_IP}:8080/Telemetry/consume \
  -d '{"topicName":"1-EDP"}'
```

**Trigger analytics:**
```bash
curl -X POST http://{FLEXIBILITY_IP}:8080/FlexibilityEvent/analyse
curl -X POST http://{GRIDBALANCING_IP}:8080/GridBalancing/analyse
curl -X POST http://{ANALYTICS_IP}:8080/EnergyAnalytics/compute
curl -X POST http://{FORECASTING_IP}:8080/FlexibilityForecasting/analyse \
  -d '{"lookbackHours":24}'
```

### Test Ollama directly
```bash
curl -X POST http://{OLLAMA_IP}:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2","prompt":"Hello, summarise this in one sentence.","stream":false}'
```
