# Asset Link Tests

Unit tests for the Asset Link microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices.

Kafka topic creation/deletion and Telemetry consumer registration/deregistration are **best-effort** (wrapped in try-catch), so all tests succeed even without a running Kafka broker or Telemetry service. The `UtilityOperator` table is seeded by a `@BeforeEach` fixture because the AssetLink service queries it to reconstruct the topic name on create and delete.

## How to run

```bash
mvn test -pl microservices/AssetLink
```

## Test cases

### GET /AssetLink — returns 200 with JSON list

Verifies the list endpoint returns HTTP 200 and a JSON array.

### GET /AssetLink/{id} — unknown ID returns 404

Requests ID 99999. Verifies HTTP 404.

### GET /AssetLink/{idProsumer}/{idUtilityOperator} — unknown pair returns 404

Requests the pair (99999, 99999). Verifies HTTP 404.

### DELETE /AssetLink/{id} — unknown ID returns 404

Requests deletion of ID 99999. Verifies HTTP 404.

### POST + GET + DELETE + GET — full create/delete lifecycle

1. `POST /AssetLink` with a valid prosumer/operator pair → expects 201 and a `Location` header.
2. `GET /AssetLink/{id}` → expects 200, confirming the record was persisted.
3. `DELETE /AssetLink/{id}` → expects 204. Kafka cleanup and Telemetry deregistration run best-effort.
4. `GET /AssetLink/{id}` → expects 404, confirming the record was removed.

### DELETE — second delete of same ID returns 404

Creates a link, deletes it (204), then deletes again. Second call expects 404, verifying the endpoint does not return 204 for an already-deleted record.
