# VPPaaS — Camunda 8 BPMN Implementation Guide

## 1. Platform & Key Facts

| Item | Value |
|---|---|
| **Engine** | Camunda 8 (C8Run 8.8.9, Zeebe) |
| **Modeler setting** | Camunda 8 — select "Camunda 8" as platform when creating each file |
| **Namespace** | `xmlns:zeebe="http://camunda.org/schema/zeebe/1.0"` |
| **HTTP connector** | `io.camunda:http-json:1` (built-in, no plugin needed) |
| **Expressions** | FEEL — prefix literals with `=`, e.g. `= "POST"`, `= approved = true` |
| **Kong placeholder** | Use `kong-ip` literally in all URLs — the deploy script replaces it with the real IP via `sed` |
| **Kong port** | `8000` |
| **URL casing** | All Kong routes are **uppercase**: `/Prosumer`, `/UtilityOperator`, `/AssetLink`, `/Telemetry`, `/FlexibilityEvent`, `/GridBalancing`, `/EnergyAnalytics`, `/FlexibilityForecasting`, `/GridZone` |

---

## 2. Common XML Patterns

### 2.1 — BPMN File Header (Camunda 8)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions
  xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
  xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"
  xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"
  xmlns:zeebe="http://camunda.org/schema/zeebe/1.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:di="http://www.omg.org/spec/DD/20100524/DI"
  xmlns:modeler="http://camunda.org/schema/modeler/1.0"
  id="Definitions_XYZ"
  targetNamespace="http://bpmn.io/schema/bpmn"
  exporter="Camunda Modeler"
  exporterVersion="5.35.0"
  modeler:executionPlatform="Camunda Cloud"
  modeler:executionPlatformVersion="8.6.0">
```

---

### 2.2 — Service Task: HTTP POST

```xml
<bpmn:serviceTask id="Task_Create" name="Create Prosumer via Kong">
  <bpmn:extensionElements>
    <zeebe:taskDefinition type="io.camunda:http-json:1" />
    <zeebe:ioMapping>
      <zeebe:input source="= &quot;POST&quot;"                                              target="method" />
      <zeebe:input source="= &quot;http://kong-ip:8000/Prosumer&quot;"                     target="url" />
      <zeebe:input source="= {name: prosumerName, FiscalNumber: fiscalNumber,
                              location: location, paymentDetails: paymentDetails}"         target="body" />
      <zeebe:output source="= response.body"                                               target="prosumerResponse" />
    </zeebe:ioMapping>
  </bpmn:extensionElements>
  <bpmn:incoming>Flow_1</bpmn:incoming>
  <bpmn:outgoing>Flow_2</bpmn:outgoing>
</bpmn:serviceTask>
```

> **Body field**: always a FEEL context `= { field: variable, ... }`.
> **Output**: `response.body` gives the parsed JSON. Use `response.body.id` to extract a specific field.

---

### 2.3 — Service Task: HTTP GET

```xml
<bpmn:serviceTask id="Task_GetTelemetry" name="Fetch Telemetry Records">
  <bpmn:extensionElements>
    <zeebe:taskDefinition type="io.camunda:http-json:1" />
    <zeebe:ioMapping>
      <zeebe:input source="= &quot;GET&quot;"                                target="method" />
      <zeebe:input source="= &quot;http://kong-ip:8000/Telemetry&quot;"      target="url" />
      <zeebe:output source="= response.body"                                 target="telemetryRecords" />
    </zeebe:ioMapping>
  </bpmn:extensionElements>
</bpmn:serviceTask>
```

---

### 2.4 — Service Task: HTTP DELETE (with path variable)

```xml
<bpmn:serviceTask id="Task_Delete" name="Decommission Prosumer via Kong">
  <bpmn:extensionElements>
    <zeebe:taskDefinition type="io.camunda:http-json:1" />
    <zeebe:ioMapping>
      <zeebe:input source="= &quot;DELETE&quot;"                                                   target="method" />
      <zeebe:input source="= &quot;http://kong-ip:8000/Prosumer/&quot; + string(prosumerId)"       target="url" />
    </zeebe:ioMapping>
  </bpmn:extensionElements>
</bpmn:serviceTask>
```

> String concatenation in FEEL: `"http://kong-ip:8000/Prosumer/" + string(prosumerId)`.

---

### 2.5 — User Task

```xml
<bpmn:userTask id="Task_KYC" name="KYC Validation">
  <bpmn:extensionElements>
    <zeebe:userTask />
    <!-- ioMapping is optional: use it to explicitly declare what variables the task reads -->
    <zeebe:ioMapping>
      <zeebe:input source="= prosumerName"    target="prosumerName" />
      <zeebe:input source="= fiscalNumber"    target="fiscalNumber" />
      <zeebe:input source="= location"        target="location" />
      <zeebe:input source="= paymentDetails"  target="paymentDetails" />
    </zeebe:ioMapping>
  </bpmn:extensionElements>
  <bpmn:incoming>Flow_1</bpmn:incoming>
  <bpmn:outgoing>Flow_2</bpmn:outgoing>
</bpmn:userTask>
```

> When the user completes this task (via Tasklist or API `POST /v2/user-tasks/{key}/completion`),
> they set the output variables: e.g. `{"variables": {"approved": true}}`.

---

### 2.6 — Call Activity (master → sub-process)

```xml
<bpmn:callActivity id="Call_Creation" name="Prosumer Creation">
  <bpmn:extensionElements>
    <zeebe:calledElement processId="ProsumerCreation" propagateAllChildVariables="true" />
  </bpmn:extensionElements>
  <bpmn:incoming>Flow_Create</bpmn:incoming>
</bpmn:callActivity>
```

> `propagateAllChildVariables="true"` makes sub-process output variables visible in the parent.
> All parent variables are automatically passed down to the called element.

---

### 2.7 — Condition Expressions (FEEL — NOT `${...}`)

```xml
<!-- Enum routing -->
<bpmn:conditionExpression>= Operation = "CREATE"</bpmn:conditionExpression>
<bpmn:conditionExpression>= Operation = "DELETE"</bpmn:conditionExpression>
<bpmn:conditionExpression>= Operation = "ABORT"</bpmn:conditionExpression>

<!-- Boolean approval -->
<bpmn:conditionExpression>= approved = true</bpmn:conditionExpression>
<bpmn:conditionExpression>= approved = false</bpmn:conditionExpression>

<!-- Array check -->
<bpmn:conditionExpression>= count(telemetryRecords) > 0</bpmn:conditionExpression>
<bpmn:conditionExpression>= count(telemetryRecords) = 0</bpmn:conditionExpression>

<!-- Null / empty check -->
<bpmn:conditionExpression>= flexibilityEvents != null</bpmn:conditionExpression>
```

---

### 2.8 — Error Boundary Event (HTTP failures)

Attach to any service task to catch connector errors (non-2xx responses):

```xml
<bpmn:boundaryEvent id="BoundaryEvent_Error" attachedToRef="Task_Create">
  <bpmn:errorEventDefinition id="ErrorDef_1" />
  <bpmn:outgoing>Flow_Error</bpmn:outgoing>
</bpmn:boundaryEvent>

<bpmn:endEvent id="EndEvent_Error" name="Provisioning Failed">
  <bpmn:errorEventDefinition />
  <bpmn:incoming>Flow_Error</bpmn:incoming>
</bpmn:endEvent>
```

---

## 3. File Inventory (14 BPMN files)

| # | File | Type | Process ID |
|---|---|---|---|
| 1 | `Prosumer-Management.bpmn` | Master | `ProsumerManagement` |
| 2 | `ProsumerCreation.bpmn` | Sub-process | `ProsumerCreation` |
| 3 | `ProsumerDeletion.bpmn` | Sub-process | `ProsumerDeletion` |
| 4 | `Utility-Operator-Management.bpmn` | Master | `UtilityOperatorManagement` |
| 5 | `UtilityOperatorCreation.bpmn` | Sub-process | `UtilityOperatorCreation` |
| 6 | `UtilityOperatorDeletion.bpmn` | Sub-process | `UtilityOperatorDeletion` |
| 7 | `Asset-Link-Management.bpmn` | Master | `AssetLinkManagement` |
| 8 | `AssetLinkCreation.bpmn` | Sub-process | `AssetLinkCreation` |
| 9 | `AssetLinkDeletion.bpmn` | Sub-process | `AssetLinkDeletion` |
| 10 | `Telemetry-Ingestion.bpmn` | Operational | `TelemetryIngestion` |
| 11 | `Flexibility-Emission.bpmn` | Operational | `FlexibilityEmission` |
| 12 | `Grid-Balancing-Recommendation.bpmn` | Operational | `GridBalancingRecommendation` |
| 13 | `Energy-Analytics.bpmn` | Operational | `EnergyAnalytics` |
| 14 | `Flexibility-Forecasting.bpmn` | Operational | `FlexibilityForecasting` |

All 14 files go into the `BPMN-Processes/` folder. The sub-process files must be deployed to Camunda alongside the master files — they are referenced by process ID via Call Activities.

---

## 4. Management Master Processes

Master processes share the same structural pattern:
`Start → User Task (choose operation) → Exclusive Gateway → Call Activity (sub-process) or Abort End`.

---

### 4.1 Prosumer-Management.bpmn

**Process ID:** `ProsumerManagement`
**Pool:** PROSUMER | **Lane:** Initiator

#### Flow

```
[Start] → [UT: Select Operation] → <GW: Choose Operation>
            ├─ CREATE  →  [CA: ProsumerCreation]
            ├─ DELETE  →  [CA: ProsumerDeletion]
            └─ ABORT   →  [End: Aborted]
```

#### Task Detail

| ID | Type | Name | Config |
|---|---|---|---|
| `StartEvent_1` | Start Event | — | Plain start |
| `Task_ChooseOperation` | User Task | "Decide what operation to do in Prosumer Management" | `zeebe:userTask`; assignee: `demo`; **output var:** `Operation` (string: CREATE / DELETE / ABORT) |
| `Gateway_Operation` | Exclusive GW | "Choose Operation" | Routes on `Operation` |
| `Call_Creation` | Call Activity | "Call Prosumer Creation Subprocess" | `processId="ProsumerCreation"` `propagateAllChildVariables="true"` |
| `Call_Deletion` | Call Activity | "Call Prosumer Deletion Subprocess" | `processId="ProsumerDeletion"` `propagateAllChildVariables="true"` |
| `EndEvent_Abort` | End Event | "Aborted" | Plain end |

#### Sequence Flow Conditions

```
Flow_Create  → condition: = Operation = "CREATE"
Flow_Delete  → condition: = Operation = "DELETE"
Flow_Abort   → condition: = Operation = "ABORT"
```

---

### 4.2 Utility-Operator-Management.bpmn

**Process ID:** `UtilityOperatorManagement`
**Pool:** UTILITY OPERATOR | **Lane:** Initiator

Identical structure to Prosumer-Management. Same CREATE / DELETE / ABORT routing.

| ID | Type | Name | Config |
|---|---|---|---|
| `Task_ChooseOperation` | User Task | "Decide what operation to do in Utility Operator Management" | output var: `Operation` |
| `Call_Creation` | Call Activity | "Call Utility Operator Creation Subprocess" | `processId="UtilityOperatorCreation"` |
| `Call_Deletion` | Call Activity | "Call Utility Operator Deletion Subprocess" | `processId="UtilityOperatorDeletion"` |

---

### 4.3 Asset-Link-Management.bpmn

**Process ID:** `AssetLinkManagement`
**Pool:** ASSET LINK | **Lane:** Initiator

Same structure. Operations: **ASSOCIATE / DECOMMISSION / ABORT** (not CREATE/DELETE — domain language matters here).

| ID | Type | Name | Config |
|---|---|---|---|
| `Task_ChooseOperation` | User Task | "Decide what operation to do in Asset Link Management" | output var: `Operation` (ASSOCIATE / DECOMMISSION / ABORT) |
| `Call_Creation` | Call Activity | "Call Asset Link Association Subprocess" | `processId="AssetLinkCreation"` |
| `Call_Deletion` | Call Activity | "Call Asset Link Decommission Subprocess" | `processId="AssetLinkDeletion"` |

```
Flow_Associate    → condition: = Operation = "ASSOCIATE"
Flow_Decommission → condition: = Operation = "DECOMMISSION"
Flow_Abort        → condition: = Operation = "ABORT"
```

---

## 5. Management Sub-Processes

Sub-processes follow the pattern:
`Start → User Task (input data) → Exclusive GW (approved?) → Service Task (Kong) → End`

The user task is where the operator fills in entity data **and** makes the KYC/validation decision. The `approved` boolean they submit drives the gateway.

---

### 5.1 ProsumerCreation.bpmn

**Process ID:** `ProsumerCreation`
**Pool:** PROSUMER CREATION | **Lane:** VPPaaS

#### Flow

```
[Start]
  → [UT: KYC Validation]           ← operator fills data + sets approved
  → <GW: KYC Approved?>
      ├─ YES → [ST: POST /Prosumer] → [End: Prosumer Registered]
      │              ↓ (error boundary)
      │         [End Error: Provisioning Failed]
      └─ NO  → [End: Registration Rejected]
```

#### Task Detail

**User Task — "KYC Validation"**
- Type: `zeebe:userTask`
- **Variables the operator must submit on completion:**

| Variable | Type | Description |
|---|---|---|
| `prosumerName` | String | Full name |
| `fiscalNumber` | Long | Tax / fiscal ID |
| `location` | String | Address |
| `paymentDetails` | String | Payment method/IBAN |
| `approved` | Boolean | KYC decision (true = pass) |

**Gateway — "KYC Approved?"**
```
YES: = approved = true
NO:  = approved = false
```

**Service Task — "Create Prosumer via Kong"**
- Connector: `io.camunda:http-json:1`

```
method  = "POST"
url     = "http://kong-ip:8000/Prosumer"
body    = {
            name:           prosumerName,
            FiscalNumber:   fiscalNumber,
            location:       location,
            paymentDetails: paymentDetails
          }

output: response.body → prosumerResponse
        response.body.id → prosumerId
```

> **Note:** `paymentDetails` is not yet in the Prosumer entity — add the field to `Prosumer.java` and the POST body before deploying.

**Error Boundary** on the service task → End Error Event "Provisioning Failed"

**End Events:**
- `EndEvent_Registered` — "Prosumer Registered"
- `EndEvent_Rejected` — "Registration Rejected"
- `EndEvent_Error` — "Provisioning Failed" (error type)

---

### 5.2 ProsumerDeletion.bpmn

**Process ID:** `ProsumerDeletion`
**Pool:** PROSUMER DELETION | **Lane:** VPPaaS

#### Flow

```
[Start]
  → [UT: Confirm Decommission]    ← operator provides prosumerId
  → [ST: DELETE /Prosumer/{id}]
  → [End: Prosumer Decommissioned]
         ↓ (error boundary)
    [End Error: Decommission Failed]
```

**User Task — "Confirm Prosumer Decommission"**

| Variable | Type | Description |
|---|---|---|
| `prosumerId` | Long | ID of the prosumer to delete |

**Service Task — "Decommission Prosumer via Kong"**

```
method  = "DELETE"
url     = "http://kong-ip:8000/Prosumer/" + string(prosumerId)
```

No output needed.

---

### 5.3 UtilityOperatorCreation.bpmn

**Process ID:** `UtilityOperatorCreation`
**Pool:** UTILITY OPERATOR CREATION | **Lane:** VPPaaS

#### Flow

```
[Start]
  → [UT: Review Operator & Zone Data]    ← operator fills data + sets approved
  → <GW: Data Valid?>
      ├─ YES → [ST: POST /UtilityOperator]
             → [ST: POST /GridZone]
             → [End: Operator & Zone Registered]
      └─ NO  → [End: Registration Rejected]
```

**User Task — "Review Operator and Zone Data"**

| Variable | Type | Description |
|---|---|---|
| `operatorName` | String | Utility operator name |
| `operatorLocation` | String | Operator address |
| `gridCellName` | String | Grid zone name (e.g. "Lisbon-Downtown") |
| `maxCapacity` | Double | Max load in MW (e.g. 50.0) |
| `boundaries` | String | Geographic boundaries description |
| `approved` | Boolean | Validation decision |

> `FiscalNumber` and `paymentDetails` should also be collected here once added to the `UtilityOperator` entity.

**Gateway — "Data Valid?"**
```
YES: = approved = true
NO:  = approved = false
```

**Service Task 1 — "Register Utility Operator via Kong"**

```
method  = "POST"
url     = "http://kong-ip:8000/UtilityOperator"
body    = {
            name:     operatorName,
            location: operatorLocation
          }

output: response.body.id → utilityOperatorId
```

**Service Task 2 — "Register Grid Zone via Kong"**

```
method  = "POST"
url     = "http://kong-ip:8000/GridZone"
body    = {
            utilityOperatorId: utilityOperatorId,
            name:              gridCellName,
            maxCapacity:       maxCapacity,
            boundaries:        boundaries
          }

output: response.body.id → gridZoneId
```

> Service Task 2 runs **after** Service Task 1 because it needs `utilityOperatorId` from the first response.

---

### 5.4 UtilityOperatorDeletion.bpmn

**Process ID:** `UtilityOperatorDeletion`

#### Flow

```
[Start]
  → [UT: Confirm Deregistration]
  → [ST: DELETE /UtilityOperator/{id}]
  → [End: Operator Deregistered]
```

**User Task variables:**

| Variable | Type | Description |
|---|---|---|
| `operatorId` | Long | ID of utility operator to delete |

**Service Task:**

```
method = "DELETE"
url    = "http://kong-ip:8000/UtilityOperator/" + string(operatorId)
```

---

### 5.5 AssetLinkCreation.bpmn

**Process ID:** `AssetLinkCreation`
**Pool:** ASSET LINK CREATION | **Lane:** VPPaaS

#### Flow

```
[Start]
  → [UT: Contract & Tariff Validation]    ← fills link data + approved
  → <GW: Contract Valid?>
      ├─ YES → [ST: POST /AssetLink]   ← automatically creates Kafka topic
             → [End: Asset Linked — Kafka Topic Created]
      └─ NO  → [End: Link Rejected]
```

**User Task — "Contract and Tariff Validation"**

| Variable | Type | Description |
|---|---|---|
| `prosumerId` | Long | Prosumer to link |
| `utilityOperatorId` | Long | Utility operator to link |
| `approved` | Boolean | Contract validation decision |

**Service Task — "Associate Asset Link via Kong"**

```
method  = "POST"
url     = "http://kong-ip:8000/AssetLink"
body    = {
            idProsumer:          prosumerId,
            idUtilityOperator:   utilityOperatorId
          }

output: response.body.id → assetLinkId
```

> This POST internally creates the Kafka topic `{assetLinkId}-{utilityOperatorId}` and registers the topic with the Telemetry consumer. This is the integration trigger for the entire telemetry pipeline.

**End Events:**
- "Asset Linked — Kafka Topic Created"
- "Link Rejected"

---

### 5.6 AssetLinkDeletion.bpmn

**Process ID:** `AssetLinkDeletion`

#### Flow

```
[Start]
  → [UT: Confirm Asset Deassociation]
  → [ST: DELETE /AssetLink/{id}]
  → [End: Asset Delinked]
```

**User Task variables:**

| Variable | Type | Description |
|---|---|---|
| `assetLinkId` | Long | ID of the asset link to remove |

**Service Task:**

```
method = "DELETE"
url    = "http://kong-ip:8000/AssetLink/" + string(assetLinkId)
```

---

## 6. Operational Processes

Operational processes are **triggered manually** (or by an external event) and call the analytical/processing microservices. They follow a pattern of:
`Start → [Script: Kong Address — NOT NEEDED in C8] → Service Task(s) → Gateway → End`.

> **No script task needed in Camunda 8.** The `kong-ip` placeholder in URLs is replaced at deploy time by the deployment script via `sed`. Do not add a Kong address script task.

---

### 6.1 Telemetry-Ingestion.bpmn

**Process ID:** `TelemetryIngestion`
**Pool:** VPPaaS | **Lane:** Executor

**What it does:** Queries the Telemetry microservice to verify stored records exist. The actual Kafka consumption is continuous and automatic — this process checks status.

#### Flow

```
[Start: Telemetry Check Request]
  → [ST: GET /Telemetry]
  → <GW: Data Available?>
      ├─ YES (count > 0) → [End: Telemetry Records Available]
      └─ NO  (count = 0) → [End: No Records Found]
```

**Service Task — "Fetch Telemetry Records via Kong"**

```
method  = "GET"
url     = "http://kong-ip:8000/Telemetry"

output: response.body → telemetryRecords
```

> `telemetryRecords` will be a JSON array of Telemetry objects.

**Gateway — "Data Available?"**

```
YES: = count(telemetryRecords) > 0
NO:  = count(telemetryRecords) = 0
```

**Variables summary:**

| Variable | Source | Type | Description |
|---|---|---|---|
| `telemetryRecords` | Service Task output | Array | All stored telemetry records |

---

### 6.2 Flexibility-Emission.bpmn

**Process ID:** `FlexibilityEmission`
**Pool:** VPPaaS | **Lane:** Executor

**What it does:** Triggers the FlexibilityEvent microservice to analyse all current telemetry. The microservice internally applies the SoC > 90% / peak-hours rule and emits Kafka events. The BPMN checks whether any events were generated.

#### Flow

```
[Start: Grid Stress Alert]
  → [ST: POST /FlexibilityEvent/trigger]
  → <GW: Events Emitted?>
      ├─ YES → [End: Flexibility Offers Published to Kafka]
      └─ NO  → [End: No Action Needed — Grid Stable]
```

**Service Task — "Trigger Flexibility Event Analysis via Kong"**

```
method  = "POST"
url     = "http://kong-ip:8000/FlexibilityEvent/trigger"
body    = {}    (no body required — microservice reads from DB internally)

output: response.body → flexibilityResponse
```

> The microservice returns a JSON response. To check if events were emitted, extract the list from the response.

**Gateway — "Events Emitted?"**

```
YES: = flexibilityResponse != null
NO:  = flexibilityResponse = null
```

> If your microservice returns a list directly: `= count(flexibilityResponse) > 0`

**Variables summary:**

| Variable | Source | Type | Description |
|---|---|---|---|
| `flexibilityResponse` | Service Task output | Object/Array | Response from trigger endpoint |

**Business Logic Note:** The FlexibilityEvent microservice applies:
- Arbitrage: `soc_percent > 90%` → "Sell" event
- Balancing: `soc_percent < 20%` → mark "Unavailable"
- Incentive: offer financial incentive for discharge

The BPMN does not re-implement this logic — it delegates entirely to the microservice.

---

### 6.3 Grid-Balancing-Recommendation.bpmn

**Process ID:** `GridBalancingRecommendation`
**Pool:** VPPaaS | **Lane:** Executor

**What it does:** Triggers the GridBalancing microservice which analyses zones across the system and recommends load shifting if a zone deficit and a zone surplus are detected simultaneously.

#### Flow

```
[Start: Balancing Request]
  → [ST: POST /GridBalancing/recommend]
  → <GW: Imbalance Detected?>
      ├─ YES → [End: Recommendations Published]
      └─ NO  → [End: Grid Already Balanced]
```

**Service Task — "Analyse Grid Zones and Generate Recommendations via Kong"**

```
method  = "POST"
url     = "http://kong-ip:8000/GridBalancing/recommend"
body    = {}    (no body required — microservice queries Telemetry/UtilityOperator/AssetLink internally)

output: response.body → recommendations
```

> The microservice internally calls Telemetry, UtilityOperator, and AssetLink services to compute zone-level aggregates.

**Gateway — "Imbalance Detected?"**

```
YES: = count(recommendations) > 0
NO:  = count(recommendations) = 0
```

> If response is an object (not array): `= recommendations != null`

**Variables summary:**

| Variable | Source | Type | Description |
|---|---|---|---|
| `recommendations` | Service Task output | Array | GridBalancingRecommendation list |

---

### 6.4 Energy-Analytics.bpmn

**Process ID:** `EnergyAnalytics`
**Pool:** VPPaaS | **Lane:** Executor

**What it does:** Triggers the EnergyAnalytics microservice to compute and store all 4 system-wide metrics defined in the spec. The 4 sequential service tasks represent the 4 distinct metric computations — they all call the same endpoint but are shown separately to make the domain logic explicit.

#### Flow

```
[Start: Analytics Request]
  → [ST: Compute Energy Discharged by Zone]
  → [ST: Compute Generated Energy by Prosumer]
  → [ST: Compute Consumed Energy by Prosumer]
  → [ST: Compute Average SoC]
  → [End: Analytics Computed and Stored]
```

**All 4 Service Tasks share the same connector config:**

```
method  = "POST"
url     = "http://kong-ip:8000/EnergyAnalytics/compute"
body    = {}    (microservice computes all types internally from Telemetry DB)

output: response.body → analyticsResult
```

> The microservice computes all 4 metrics in one call and stores them with `analyticsType` labels:
> `DISCHARGED_BY_ZONE`, `GENERATED_BY_PROSUMER`, `CONSUMED_BY_PROSUMER`, `AVERAGE_SOC`.
> Showing 4 tasks in the BPMN makes the domain model explicit and directly maps to the spec's 4 metrics.

**Alternative (leaner):** Call once and go to end. The 4-task version is preferred for the report.

**Variables summary:**

| Variable | Source | Type | Description |
|---|---|---|---|
| `analyticsResult` | Each task output | Object | `{computed: true, timestamp: "..."}` |

---

### 6.5 Flexibility-Forecasting.bpmn

**Process ID:** `FlexibilityForecasting`
**Pool:** VPPaaS | **Lane:** Executor

**What it does:** The most complex operational process. Calls the FlexibilityForecasting microservice which internally fetches past FlexibilityEvent logs and sends them to Ollama (llama3.2) for sentiment and success-rate analysis. A human operator then reviews the AI output and decides to accept or discard the forecast.

#### Flow

```
[Start: Forecast Request]
  → [ST: Query LLM — POST /FlexibilityForecasting/forecast]
  → [UT: Review AI Forecast Results]       ← operator reads forecastResult, sets approved
  → <GW: Forecast Approved?>
      ├─ YES → [End: Forecast Accepted]
      └─ NO  → [End: Forecast Discarded]
```

**Service Task — "Query LLM for Flexibility Forecast via Kong"**

```
method  = "POST"
url     = "http://kong-ip:8000/FlexibilityForecasting/forecast"
body    = {}    (microservice fetches FlexibilityEvent logs internally and sends to Ollama)

output: response.body → forecastResult
```

> `forecastResult` will be a string — the LLM's analysis of the past events (sentiment + success rate).

**User Task — "Review AI Forecast Results"**
- Type: `zeebe:userTask`
- The operator reads `forecastResult` (shown by Tasklist) and submits:

| Variable | Type | Description |
|---|---|---|
| `approved` | Boolean | Accept (true) or discard (false) the forecast |

**Gateway — "Forecast Approved?"**

```
YES: = approved = true
NO:  = approved = false
```

**End Events:**
- "Forecast Accepted" — the forecast is considered valid for grid planning
- "Forecast Discarded" — operator rejects the AI result

> **Note:** There is no `POST /FlexibilityForecasting/save` endpoint. "Accepted" is a process state only — the forecast string in `forecastResult` can be logged via Camunda's process history.

---

## 7. Endpoint Reference

| Microservice | Method | Path | Body Fields | Returns |
|---|---|---|---|---|
| Prosumer | POST | `/Prosumer` | `name`, `FiscalNumber`, `location`, `paymentDetails`* | Prosumer `{id, name, ...}` |
| Prosumer | GET | `/Prosumer` | — | Array of Prosumer |
| Prosumer | DELETE | `/Prosumer/{id}` | — | 204 |
| UtilityOperator | POST | `/UtilityOperator` | `name`, `location` | UtilityOperator `{id, ...}` |
| UtilityOperator | DELETE | `/UtilityOperator/{id}` | — | 204 |
| GridZone | POST | `/GridZone` | `utilityOperatorId`, `name`, `maxCapacity`, `boundaries` | GridZone `{id, ...}` |
| GridZone | DELETE | `/GridZone/{id}` | — | 204 |
| AssetLink | POST | `/AssetLink` | `idProsumer`, `idUtilityOperator` | AssetLink `{id, ...}` |
| AssetLink | DELETE | `/AssetLink/{id}` | — | 204 |
| Telemetry | GET | `/Telemetry` | — | Array of Telemetry |
| FlexibilityEvent | POST | `/FlexibilityEvent/trigger` | (none) | Events array or count |
| FlexibilityEvent | GET | `/FlexibilityEvent` | — | Array of FlexibilityEvent |
| GridBalancing | POST | `/GridBalancing/recommend` | (none) | Array of recommendations |
| EnergyAnalytics | POST | `/EnergyAnalytics/compute` | (none) | `{computed: true, timestamp}` |
| FlexibilityForecasting | POST | `/FlexibilityForecasting/forecast` | (none) | Forecast string |

> `*` `paymentDetails` must be added to the Prosumer entity before using it in the BPMN body.

---

## 8. Variable Reference by Process

### Management Sub-Processes

| Process | Input Variables (set at User Task) | Key Output Variables |
|---|---|---|
| ProsumerCreation | `prosumerName`, `fiscalNumber`, `location`, `paymentDetails`, `approved` | `prosumerId` |
| ProsumerDeletion | `prosumerId` | — |
| UtilityOperatorCreation | `operatorName`, `operatorLocation`, `gridCellName`, `maxCapacity`, `boundaries`, `approved` | `utilityOperatorId`, `gridZoneId` |
| UtilityOperatorDeletion | `operatorId` | — |
| AssetLinkCreation | `prosumerId`, `utilityOperatorId`, `approved` | `assetLinkId` |
| AssetLinkDeletion | `assetLinkId` | — |

### Operational Processes

| Process | Key Variables |
|---|---|
| TelemetryIngestion | `telemetryRecords` (array) |
| FlexibilityEmission | `flexibilityResponse` |
| GridBalancingRecommendation | `recommendations` (array) |
| EnergyAnalytics | `analyticsResult` |
| FlexibilityForecasting | `forecastResult` (string), `approved` (boolean) |

---

## 9. Microservice Gaps to Fix Before Building BPMNs

These must be fixed in the microservice code — the BPMNs assume these fields/endpoints exist:

| # | Microservice | Gap | Fix |
|---|---|---|---|
| 1 | Prosumer | Missing `paymentDetails` field | Add `String paymentDetails` to `Prosumer.java` entity and include in `POST /Prosumer` |
| 2 | UtilityOperator | Missing `FiscalNumber` field | Add `Long FiscalNumber` to `UtilityOperator.java` entity |

---

## 10. Deployment Notes

All 14 files are deployed by the `deploy_bpmn_processes()` function in `DeploymentSprint2.sh`:

```bash
for bpmn in BPMN-Processes/*.bpmn; do
    tmpfile="/tmp/$(basename "$bpmn")"
    sed "s|kong-ip|$addressKong|g" "$bpmn" > "$tmpfile"
    curl -u demo:demo -X POST "http://$addressCamunda:8080/v2/deployments" \
         -F "resources=@$tmpfile"
done
```

The `sed` command replaces every occurrence of `kong-ip` with the live Kong EC2 hostname before uploading to Camunda. This is why **no script task is needed** to resolve the Kong address at runtime — it is baked in at deploy time.

Sub-process files (`ProsumerCreation.bpmn`, `ProsumerDeletion.bpmn`, etc.) **must be deployed in the same batch** as their master processes for the Call Activities to resolve correctly.
