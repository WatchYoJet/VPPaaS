# VPPaaS Documentation

This directory contains all project documentation.

## Microservices

API documentation for each microservice. All endpoints are exposed through Kong on port `8000`.

| Microservice | Path | Description |
|---|---|---|
| [Prosumer](microservices/prosumer.md) | `/Prosumer` | Manages prosumer registration and data |
| [Utility Operator](microservices/utility-operator.md) | `/UtilityOperator`, `/GridZone` | Manages utility operators and their grid zones |
| [Asset Link](microservices/asset-link.md) | `/AssetLink` | Links prosumers to utility operators and provisions Kafka topics |
| [Telemetry](microservices/telemetry.md) | `/Telemetry` | Stores and retrieves asset telemetry readings |
| [Energy Analytics](microservices/energy-analytics.md) | `/EnergyAnalytics` | Computes and stores energy aggregations per zone and prosumer |
| [Flexibility Event](microservices/flexibility-event.md) | `/FlexibilityEvent` | Detects and stores flexibility events from telemetry |
| [Flexibility Forecasting](microservices/flexibility-forecasting.md) | `/FlexibilityForecasting` | Generates AI-based flexibility forecasts using Ollama |
| [Grid Balancing](microservices/grid-balancing.md) | `/GridBalancing` | Produces grid balancing recommendations between zones |

## BPMN Processes

Camunda 8 process documentation. All processes run on C8Run - Tasklist on `/tasklist`, Operate on `/operate`, login `demo`/`demo`.

| Process | Description |
|---------|-------------|
| [Prosumer Management](bpmn/prosumer-management.md) | Two-pool negotiation handshake for prosumer creation |
| [Utility Operator Management](bpmn/utility-operator-management.md) | Single-pool sequential flow for operator creation |
| [Asset Link Management](bpmn/asset-link-management.md) | Three-pool collaboration linking a prosumer to an operator and provisioning Kafka |
| [Energy Analytics](bpmn/energy-analytics.md) | Triggers analytics computation and shows the timestamp |
| [Flexibility Emission](bpmn/flexibility-emission.md) | Triggers flexibility event evaluation and shows the event count |
| [Flexibility Forecasting](bpmn/flexibility-forecasting.md) | AI-generated forecast with operator approve/reject |
| [Grid Balancing Recommendation](bpmn/grid-balancing-recommendation.md) | Triggers balancing recommendation and confirms receipt |

Deploy all processes with:

```bash
bash tests/deploy-bpmns.sh
```

## Tests

JUnit/QuarkusTest unit tests for each microservice. All tests run in-process against an in-memory database provided by Quarkus DevServices. Tests that depend on external services (Telemetry, Kafka, Ollama) verify that the endpoint responds with structured JSON rather than testing the full integration path.

| Microservice | Description |
|---|---|
| [Prosumer](tests/prosumer.md) | CRUD operations including create, update, and delete lifecycle |
| [Utility Operator](tests/utility-operator.md) | UtilityOperator and GridZone CRUD operations |
| [Asset Link](tests/asset-link.md) | Read and not-found scenarios (creation requires Kafka and Telemetry) |
| [Telemetry](tests/telemetry.md) | Read endpoints and end-to-end simulator integration test |
| [Energy Analytics](tests/energy-analytics.md) | Read endpoint and compute trigger response |
| [Flexibility Event](tests/flexibility-event.md) | Read endpoints and trigger response |
| [Flexibility Forecasting](tests/flexibility-forecasting.md) | Forecast trigger response |
| [Grid Balancing](tests/grid-balancing.md) | Read endpoint and recommend trigger response |
