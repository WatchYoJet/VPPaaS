# Energy Analytics Tests

Unit tests for the Energy Analytics microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices and starts empty.

Note: `POST /EnergyAnalytics/compute` calls the Telemetry service and Kafka, which are unavailable in the test environment. The endpoint returns a structured JSON error response rather than a 2xx.

## How to run

```bash
mvn test -pl microservices/EnergyAnalytics
```

## Test cases

### GET /EnergyAnalytics - returns 200 with JSON list

Verifies that the list endpoint returns HTTP 200 and a JSON array. The database starts empty, so an empty array is expected.

### POST /EnergyAnalytics/compute - responds with JSON

Triggers a computation cycle. Because the Telemetry service is unreachable in the test environment, the endpoint returns HTTP 500 with a structured JSON error body. The test verifies the response is JSON and is not null.
