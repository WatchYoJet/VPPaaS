# Prosumer Tests

Unit tests for the Prosumer microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices (H2 in-memory) and seeded with 4 records on startup.

## How to run

```bash
mvn test -pl microservices/Prosumer
```

## Test cases

### GET /Prosumer - returns 200 with JSON list

Verifies that the list endpoint returns HTTP 200 and a JSON array.

### GET /Prosumer/{id} - existing record returns 200

Requests seed record with ID 1. Verifies HTTP 200, and that `id` and `name` fields are present.

### GET /Prosumer/{id} - unknown ID returns 404

Requests ID 99999. Verifies HTTP 404.

### POST /Prosumer - creates record and returns 201

Creates a new prosumer with the following data:

```json
{
  "name": "TestProsumer",
  "FiscalNumber": 111222333,
  "location": "Lisbon"
}
```

Verifies HTTP 201 and a `Location` header. Then fetches the created record by ID and confirms `name` and `location` match. Cleans up by deleting the record.

### PUT /Prosumer/{id}/{name}/{FiscalNumber}/{location} - updates record and returns 204

Creates a record, updates it via the path-parameter PUT endpoint, then fetches it again to confirm the `name` changed. Cleans up afterwards.

### DELETE /Prosumer/{id} - unknown ID returns 404

Requests deletion of ID 99999. Verifies HTTP 404.
