# Grid Balancing Tests

Unit tests for the Grid Balancing microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices and starts empty.

Note: `POST /GridBalancing/recommend` calls the Telemetry, Utility Operator, and Asset Link services, all of which are unavailable in the test environment. The endpoint returns a structured JSON error response rather than a 2xx.

## How to run

```bash
mvn test -pl microservices/GridBalancing
```

## Test cases

### GET /GridBalancing — returns 200 with JSON list

Verifies that the list endpoint returns HTTP 200 and a JSON array. The database starts empty, so an empty array is expected.

### POST /GridBalancing/recommend — responds with JSON

Triggers a grid balancing recommendation cycle. Because the Telemetry, Utility Operator, and Asset Link services are unreachable in the test environment, the endpoint returns HTTP 500 with a structured JSON error body. The test verifies the response is JSON and is not null.
