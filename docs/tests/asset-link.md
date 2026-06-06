# Asset Link Tests

Unit tests for the Asset Link microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices and starts empty.

Note: the POST /AssetLink endpoint calls Kafka and the Telemetry service at creation time. Both are unavailable in the test environment, so creation is not tested at unit level.

## How to run

```bash
mvn test -pl microservices/AssetLink
```

## Test cases

### GET /AssetLink — returns 200 with JSON list

Verifies that the list endpoint returns HTTP 200 and a JSON array.

### GET /AssetLink/{id} — unknown ID returns 404

Requests ID 99999. Verifies HTTP 404.

### GET /AssetLink/{idProsumer}/{idUtilityOperator} — unknown pair returns 404

Requests the pair (99999, 99999). Verifies HTTP 404.

### DELETE /AssetLink/{id} — unknown ID returns 404

Requests deletion of ID 99999. Verifies HTTP 404.
