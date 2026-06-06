# VPPaaS — Project Specification Transcript
# Source: VPPaaS-IE2026pdf.pdf (17 pages)
# Course: Enterprise Integration 2026 — Instituto Superior Técnico, Universidade de Lisboa

---

## Table of Contents

1. Project Context
2. Core Concepts Definition
3. Business Architecture
4. Application Integration Reference Architecture
5. Data Integration Architecture
6. Technological Integration Architecture
   - I. Prosumer Management
   - II. Utility Operator Management
   - III. Asset Link Management
   - IV. Telemetry Ingestion
   - V. Flexibility Emission
   - VI. Grid Balancing Recommendation
   - VII. Energy Analytics
   - VIII. Flexibility Forecasting (AI)
7. Event Producer Tool
8. Deliverables & Deadlines

---

## 1. Project Context

Your EI project is located in the innovative concept of Virtual Power Plant-as-a-Service (VPPaaS). For short, a VPPaaS is a cloud-based distributed power plant that aggregates the capacities of heterogeneous Distributed Energy Resources (DER) — such as solar panels, home batteries, electric vehicles, and others — for the purposes of enhancing power generation, as well as trading or selling power on the electricity market.

In a classical approach each DER acts as "Energy Silos" and a grid cannot "see" or control these assets as a unified group. The lack of a standardized integration layer prevents the aggregation of these small energy packets into a volume significant enough to influence the grid. The challenge of your project is to create a system that enables a unified view of generation and storage capacity.

> "A VPP is a network that integrates dispersed energy resources, orchestrating them to operate cohesively as an extensive power generation facility. The primary goal of a VPP is to enhance grid stability, efficiency, and reliability while mitigating emissions and costs associated with conventional power generation. Generally, the architecture of a VPP contains three essential elements. Firstly, a diverse array of energy assets, ranging from solar panels and wind turbines to energy storage systems and energy-efficient buildings, form the foundation of the VPP. Energy Management Systems (EMS) play a pivotal role in efficiently overseeing various energy resources, including dispatchable power plants, intermittent generation units, storage facilities, and demand response systems. The second component is the communications network, facilitating data exchange and control signals among different VPP elements. For instance, EMS facilitates energy trading within the VPP through bidirectional communication and real-time status updates. The third component, the control system, handles data collection and analysis, power market prediction, resource modelling, aggregation, and transaction decisions. It oversees the real-time operation of distributed energy production and consumption. Cloud-based software is used for data analysis, optimization, and decision-making, targeting cost reduction, pollution minimization, and profit maximization."

Therefore, your project's goal is to develop an information system to support the operation of a VPPaaS provider. The VPPaaS is designed to offer unique benefits, such as stabilizing the grid during peak demand and allowing individual "Prosumers" (producers-consumers) to monetize their hardware. Additionally, the VPPaaS serves as an avenue for inter-zone cooperation, balancing energy loads between different geographic grid zones.

Each prosumer is connected to a grid operator by an asset link through a digital contract. To optimize its operation, multiple asset links can be contracted by a prosumer. VPPaaS facilitates the establishment of this commercial relationship between prosumers and grid operators and offers added value services to optimize the overall operating conditions benefiting both actors.

---

## 2. Core Concepts Definition

**Prosumer** — is an entity (household or business) that consumes electricity but also possesses generation or storage capabilities. They register in VPPaaS to monetize their assets.

**Utility Operator** — represents the energy manager of a specific grid cell that can establish the asset links with prosumers. They register in VPPaaS to offer their infrastructure energy supply services.

**Grid Cell** — represents a specific geographic or logical cluster (e.g., "Lisbon-Downtown", "Porto-Industrial"). Each zone has specific capacity constraints and is managed by a specific utility operator.

**Asset Link** — is the digital contract that associates a specific Prosumer's hardware (e.g., a Battery) with a specific Utility Operator. This link authorizes the VPPaaS to monitor and control that asset.

**Telemetry** — the system relies on high-frequency "Telemetry Events." These are data packets sent by the Asset Link containing real-time status (State of Charge, Current Output, Voltage, Connection Status, or others depending on the hardware). VPPaaS relies on telemetry to provide analytics and uses telemetry to produce decisions affecting the operational conditions of the grid.

**Flexibility Event** — is a command or offer generated by the VPPaaS. For example, if the grid is stressed, the system emits an event offering a financial incentive for prosumers to discharge energy.

**Grid Balancing Recommendation** — this concept involves identifying opportunities to shift load between Grid Zones. If Zone A is facing a deficit and Zone B has a surplus, the system recommends specific actions to balance the two.

---

## 3. Business Architecture

Two major business problems are targeted to be solved by the project:

### a) Onboarding and Decommissioning of Prosumers, Utility Operators, and Prosumer Assets

The viability of a VPP relies on the mass aggregation of thousands of small resources. The problem lies in the high friction of the Onboarding process. It is a multi-layered workflow that requires synchronizing Business Validation (KYC — Know Your Customer, contract signing, tariff selection) with Technical Provisioning (IoT device handshake, protocol compatibility checks, and capacity verification). Manual onboarding is unscalable; therefore, the system must automate the "handshake" between a new Prosumer's hardware (e.g., a Tesla Powerwall) and the VPP control center, ensuring the asset is legitimate and controllable before it enters the market.

**The Risk of "Zombie" Assets (Decommissioning):** Equally critical is the Decommissioning process. In dynamic grid environments, prosumers move houses, sell electric vehicles, or switch energy providers. If an asset is physically disconnected but remains logically active in the VPP database, the system will attempt to dispatch commands to a "Phantom Asset." This leads to Grid Balancing Errors — where the VPP promises energy to the Utility Operator that it physically cannot deliver because the assets no longer exist. The challenge is to design a strict "Off-boarding" orchestration that instantly revokes security keys, stops telemetry ingestion, and updates the aggregate capacity calculations to maintain grid reliability.

### b) Emergency Demand Response and Critical Event Handling

**The Latency and Concurrency Challenge:** While standard grid balancing is driven by economic signals (hourly prices), Emergency Demand Response is driven by grid stability (frequency deviations or line overloads). In these scenarios, the Grid Operator (DSO/TSO) requires a load reduction of specific MegaWatts (MW) within seconds to prevent a blackout. The integration challenge here is Massive Concurrency. The VPP platform must receive a single "Critical Event" signal and instantly broadcast shut-down commands to thousands of disparate assets (EV chargers, Batteries, ...) simultaneously.

**Use Case Actors:**
- Prosumer: (un)Register Prosumer, Submit telemetry events, Enable the Control of an Asset Link, Analyse the prediction of future Energy Usage
- IoT: Submit telemetry events (automated)
- Utility Operator: (un)Register GridZone, Receive a flexibility emission suggestion, Analyse past Energy Usage, Recommend shift load to balance Grid Zones

---

## 4. Application Integration Reference Architecture

Four integration patterns (from left to right in Figure 2):

1. **Pattern 1**: Manages a business entity stored in a database using a JDBC interface and exposed by REST.
2. **Pattern 2** (most comprehensive): Keeps a business data entity consistent between a Kafka cluster and a database, and exposes that composed entity through REST.
3. **Pattern 3**: Manages a business entity against a Kafka cluster by exposing a REST interface.
4. **Pattern 4**: Artificial intelligence exposes an API-to-API gateway offering an Ollama server deployed at EC2 to support the business process decisions.

---

## 5. Data Integration Architecture

**Domain Model Classes:**

- **Prosumer**: ID (ProsumerID), Name (String)
- **UtilityOperator**: ID (UtilityOperatorID), Name (String)
- **GridCell**: ID (GridCellID), Location (LocationType)
- **AssetLink**: ID (AssetLinkID); operations: Association(Prosumer, UtilityOperator): ResultCode, Deassociation(Prosumer, UtilityOperator): ResultCode
- **Asset**: ID (AssetID), Postal Code Type
  - **Solar Inverter (PV)**: CurrentGeneration (kW), Daily Total (kWh), Operating Grid Frequency (Hz), Operating Grid Voltage (Volt)
  - **Battery Energy Storage (BESS)**: Available energy (kWh), Current Output (kW), Maximum Capacity (kW), State of Charge (SoC) (Percentage), State of Health (Percentage)
  - **EV Charger (Wallbox/OCPP)**: Charging Rate (kW), EV State of charge (SoC) (Percentage), Plug Status (AVAILABLE/OCCUPIED/CHARGING/FAULTED), Session Energy (kWh)
- **Telemetry**: MessageID (TelemetryID), Timestamp (int), Postal Code (Postal Code Type), Address (String)
- **FlexibilityEvent**: ID (FlexibilityEventID)
- **GridBalancingRecommendation**
- **EnergyAnalytics**: Energy Discharged by Zone, Generated Energy by Prosumer, Consumed Energy by Prosumer, Average SoC

**Data Types**: Hz, Volt, kW, kWh, Percentage, AssetLinkID, GridCellID, AssetID, FlexibilityEventID, LocationType, ResultCode, PlugStatus (AVAILABLE, OCCUPIED, CHARGING, FAULTED)

---

## 6. Technological Integration Architecture

Each class in the domain model represents a key concept that needs to be managed by a dedicated microservice. "A microservice should be independently releasable services that are modelled around a business domain."

### I. Prosumer Management

- Responsible for registering and managing Prosumers (Name, Fiscal ID, Location, Payment Details).
- Responsible to identify the assets of that prosumer.
- **Integration Pattern**: Business entity in database (JDBC) exposed via REST.

### II. Utility Operator Management

- Responsible for registering and managing utility operators (Name, Fiscal ID, Location, Payment Details).
- Manages the lifecycle of Grid Zones (Creation, updating max capacity, setting geographic boundaries).
- Stores grid constraints (e.g., "Max Load: 50MW").
- **Integration Pattern**: Business entity in database (JDBC) exposed via REST.

### III. Asset Link Management

- Manages the association between a Prosumer and a Grid Zone.
- **Integration Requirement**: When a link is active, it must publish to a Kafka Topic `Asset-at-Zone` (Format: `AssetID-ZoneID`) to enable telemetry ingestion for that specific pair.
- **Integration Pattern**: Kafka producer + database + REST.

### IV. Telemetry Ingestion

- High Volume Service: Consumes energy readings (kWh, voltage, status) from the prosumer's simulators.
- Data depends on the type of Asset involved: Solar Inverter, Battery Energy Storage, or EV Charger.
- Stores time-series data regarding asset performance.
- **Integration Pattern**: Kafka consumer + database + REST.

### V. Flexibility Emission

- Analyses incoming telemetry. If an asset reports high capacity (>90% charge) during defined "Peak Hours," this service generates a "Flexibility Offer" and publishes it to the Flexibility-Offers Kafka topic.

**Example flexibility emission rules:**
- Arbitrage Logic: If `soc_percent > 90%` AND `current_market_price` is HIGH → Trigger Sell
- Balancing Logic: If `soc_percent < 20%` → Mark as "Unavailable" for balancing requests
- OTHER: Offer a financial incentive for discharge energy to a prosumer

### VI. Grid Balancing Recommendation

- Analyses aggregated data across different Grid Zones.
- If a Zone exceeds its safety threshold, this service scans neighbouring zones for surplus and produces a "Balancing Recommendation" event.

### VII. Energy Analytics

- Aggregates system-wide data: "Energy Discharged by Zone", "Generated Energy by Prosumer", "Consumed Energy by Prosumer", "Average SoC".
- Produces calculated results to Kafka topics for dashboarding.

### VIII. Flexibility Forecasting (AI)

The Flexibility Forecasting encompasses:
- Use of a Large Language Model (Ollama) to analyze the unstructured logs of past Flexibility Events.
- **Goal**: Determine the sentiment and success rate of past events (e.g., analyzing log text to see if the "Discharge" command resulted in a successful "Grid Stable" state).
- **Integration Pattern**: Ollama REST API + FlexibilityEvent service + REST exposure.

---

## 7. Event Producer Tool

A VPP aggregates different devices (Solar, Batteries, EVs); the telemetry structure must be polymorphic or contain specific subsets of data. The event producer tool acts as a simulator of production and consumption using the asset links. The tool starts by discovering all topics available in the Kafka cluster (each topic is a different AssetLinkID-UtilityOperator) and then randomizes messages for all discovered topics.

**Topic naming format**: `{AssetLinkID}-{UtilityOperator}` (e.g., `560987123-EDP`)

### Common Header (Metadata) — every telemetry packet:

| Field | Type | Description |
|---|---|---|
| seqKey | UUID | Unique ID for the telemetry packet (de-duplication) |
| timestamp | ISO8601 | Precise time of reading |
| asset_id | String | Unique hardware ID (e.g., BATT-001) |
| asset_type | String | BATTERY, SOLAR, or EV_CHARGER |
| grid_cell_id | String | The ID of the zone this asset belongs to |

### Battery Energy Storage (BESS):

| Data Point | JSON Field | Unit | Why it's needed |
|---|---|---|---|
| State of Charge | soc_percent | % | Core Logic: determines if we can sell (High SoC) or need to buy (Low SoC) |
| Available Energy | energy_available_kwh | kWh | Calculates exactly how long we can discharge at full power |
| Current Output | active_power_kw | kW | (+ve = Discharging, -ve = Charging). Verify if command was obeyed |
| Max Capacity | max_discharge_power_kw | kW | Speed limit; can't request 10kW from a 5kW battery |
| State of Health | soh_percent | % | Long-term maintenance; if SoH < 70%, exclude from aggressive trading |
| Status | connection_status | Enum | ONLINE, OFFLINE, FAULT, MAINTENANCE |

### Solar Inverter (PV):

| Data Point | JSON Field | Unit | Why it's needed |
|---|---|---|---|
| Current Generation | generation_kw | kW | Real-time output |
| Daily Total | daily_yield_kwh | kWh | Analytics/reporting |
| Grid Voltage | ac_voltage_v | Volts | If Voltage > 253V, inverter might trip |
| Frequency | grid_frequency_hz | Hz | If Freq < 49.8Hz, VPP might trigger emergency discharge |

### EV Charger (Wallbox/OCPP):

| Data Point | JSON Field | Unit | Why it's needed |
|---|---|---|---|
| Plug Status | connector_status | Enum | AVAILABLE, OCCUPIED, CHARGING, FAULTED |
| Charging Rate | charging_power_kw | kW | The load we can "shed" if grid is stressed |
| Session Energy | session_energy_kwh | kWh | For billing the user |
| EV SoC | ev_soc_percent | % | Advanced: only available if car communicates it (ISO 15118) |

### Example JSON Messages:

**BESS Payload:**
```json
topic = 560987123-EDP, key=b0002dd9-3ab0-4a0b-9b4c-74790d7e3849
{
  "timeStamp": "2026-02-20 13:39:53.401",
  "asset_type": "BATTERY",
  "asset_id": "560987123",
  "grid_cell_id": "AUSTIN-DT",
  "payload": {
    "energy_available_kwh": 13.936685931917559,
    "max_discharge_power_kw": 2.947349764012512,
    "active_power_kw": -7.220102938275808,
    "connection_status": "MAINTENANCE",
    "soh_percent": 31.943940694715046,
    "soc_percent": 92.22976493508132
  }
}
```

**Solar Payload:**
```json
topic = 560987123-EDP, key=f516b174-2c5f-405d-9891-450ed19c4e4c
{
  "timeStamp": "2026-02-20 15:00:30.638",
  "asset_type": "SOLAR",
  "asset_id": "560987123",
  "grid_cell_id": "CAIRO-ND",
  "payload": {
    "ac_voltage_v": 254.69491311862646,
    "generation_kw": 0.5640583520961961,
    "grid_frequency_hz": 49.84521461297455,
    "daily_yield_kwh": 63.7981840024461
  }
}
```

**EV Charger Payload:**
```json
topic = 560987123-EDP, key=440ce0b6-8ac7-4926-8650-36d43ca360fb
{
  "timeStamp": "2026-02-20 15:20:49.816",
  "asset_type": "EV_CHARGER",
  "asset_id": "560987123",
  "grid_cell_id": "SANTOS-IN",
  "payload": {
    "charging_power_kw": 0.9642079408177404,
    "connector_status": "AVAILABLE",
    "session_energy_kwh": 13.627434098664882,
    "ev_soc_percent": 50.49963512002662
  }
}
```

Tool repository: https://github.com/Enterprise-Integration-IST-2026/VPPaaS-EventProducer

---

## 8. Deliverables & Deadlines

### 1st Sprint (Deadline: 10/5/2026 23:59)

1. Design your own understanding of the information flow considering the requirements and the architecture of VPPaaS. Specify Kafka topics and partitions, as well as microservices using UML sequence diagrams (https://plantuml.com/).
2. Setup and deployment of the Kafka Cluster using TERRAFORM. For testing purposes use the VPPaaS producer and create the needed topics by command line.
3. Implementation of the following microservices using (Quarkus or AWS Lambda) and AWS RDS and TERRAFORM (excluding Camunda and Kong — business process implementation is Sprint 2):
   - Prosumer
   - UtilityOperator
   - AssetLink
   - Telemetry Ingestion
   - Flexibility Emission
   - Grid Balancing
   - Energy Analytics
   - Flexibility Forecasting (AI)
4. Documentation of tests considering all the previous deliverables.
5. Documentation for the source code, Terraform script files, installation procedures, and parametrizations.

**Submission**: One single ZIP file via Fénix containing the report PDF and all developed code, scripts, and other artifacts.

### 2nd Sprint (Deadline: 7/6/2026 23:59)

1. Development of the support business processes using Camunda platform, Kong, and all required integrations. All developed microservices must be used by the business processes:
   - Prosumer Management
   - Utility Operator Management
   - Asset Link Management
   - Telemetry Ingestion
   - Flexibility Emission
   - Grid Balancing Recommendation
   - Energy Analytics
   - Flexibility Forecasting (AI)
2. Documentation of end-to-end tests considering the full business processes execution.
3. Documentation for the source code, Terraform script files, BPMN files, installation procedures, and parametrizations.

**Submission**: One single ZIP file via Fénix containing the report PDF and all developed code, scripts, and other artifacts.
