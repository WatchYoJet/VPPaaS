# Telemetry Tests

Unit and integration tests for the Telemetry microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices and starts empty. Kafka is provided by Quarkus DevServices (requires Docker).

## How to run

```bash
mvn test -pl microservices/Telemetry
```

## Test cases - TelemetryResourceTest

### GET /Telemetry - returns 200 with JSON list

Verifies that the list endpoint returns HTTP 200 and a JSON array. The database starts empty, so an empty array is expected.

### GET /Telemetry/{id} - unknown ID returns 404

Requests ID 99999. Verifies HTTP 404.

### POST /Telemetry/Consume - starts consumer and returns 200

Registers a consumer for the topic `test-topic-junit`. Verifies HTTP 200. A background `DynamicTopicConsumer` thread is started for the given topic.

## Test cases - TelemetrySimulatorTest

This test verifies the full end-to-end telemetry ingestion path: Simulator - Kafka - Telemetry service - Database.

**Prerequisites:**
- Docker must be running (Quarkus DevServices provisions Kafka automatically).
- `tests/VPPaaSSimulator.jar` must be present at `../../tests/VPPaaSSimulator.jar` relative to the `microservices/Telemetry` directory. If the JAR is not found, the test is skipped automatically.

### simulator_populatesTelemetryViaKafka

1. Registers a Kafka consumer for topic `1-ArcoCegoLisbon` via `POST /Telemetry/Consume`.
2. Waits 3 seconds for the consumer thread to connect and subscribe.
3. Launches `VPPaaSSimulator.jar` with `--filterprefix 1` and `--throughput 2`, pointing at the DevServices Kafka broker.
4. Polls `GET /Telemetry` every 2 seconds for up to 30 seconds.
5. Asserts that at least one telemetry record appears in the database.
6. Terminates the simulator process.
