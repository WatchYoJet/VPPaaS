# Utility Operator Tests

Unit tests for the Utility Operator microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices and seeded with 4 utility operators on startup. The GridZone table starts empty.

## How to run

```bash
mvn test -pl microservices/UtilityOperator
```

## Test cases - UtilityOperator

### GET /UtilityOperator - returns 200 with JSON list

Verifies that the list endpoint returns HTTP 200 and a JSON array.

### GET /UtilityOperator/{id} - existing record returns 200

Requests seed record with ID 1. Verifies HTTP 200 and that `id` and `name` are present.

### GET /UtilityOperator/{id} - unknown ID returns 404

Requests ID 99999. Verifies HTTP 404.

### POST /UtilityOperator - creates record and returns 201

Creates a new utility operator with the following data:

```json
{
  "name": "TestOperator",
  "location": "Braga"
}
```

Verifies HTTP 201 and a `Location` header. Fetches the created record and confirms `name` matches. Cleans up by deleting the record.

### PUT /UtilityOperator/{id}/{name}/{location} - updates record and returns 204

Creates a record, updates it, then fetches it again to confirm the `name` changed to `NewName`. Cleans up afterwards.

## Test cases - GridZone

### GET /GridZone - returns 200 with JSON list

Verifies that the grid zone list endpoint returns HTTP 200 and a JSON array.

### POST /GridZone - creates zone and returns 201

Creates a new grid zone with the following data:

```json
{
  "utilityOperatorId": 1,
  "name": "ZoneTest",
  "maxCapacity": 500.0,
  "boundaries": "poly"
}
```

Verifies HTTP 201 and a `Location` header. Fetches the created zone and confirms `name` equals `ZoneTest` and `maxCapacity` equals `500.0`. Cleans up by deleting the zone.

### GET /GridZone/operator/{operatorId} - returns 200

Requests all zones for operator ID 1. Verifies HTTP 200 and a JSON array.

### GET /GridZone/{id} - unknown ID returns 404

Requests ID 99999. Verifies HTTP 404.
