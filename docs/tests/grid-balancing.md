# Grid Balancing Tests

Unit tests for the Grid Balancing microservice using QuarkusTest and RestAssured. The database is managed by Quarkus DevServices.

Tests are split into two classes:

- **`GridBalancingResourceTest`** - basic endpoint smoke tests with no external service dependencies.
- **`GridBalancingActTest`** - full logic tests for `POST /GridBalancing/act/{id}`, using [WireMock](https://wiremock.org/) (`wiremock-jre8-standalone:2.35.2`) to mock the AssetLink and UtilityOperator services. WireMock is started via a `@QuarkusTestResource` (`WireMockExternalServices`) that overrides the `assetlink.service.url` and `utilityoperator.service.url` config properties before the app boots.

## How to run

```bash
mvn test -pl microservices/GridBalancing
```

## Test cases

### GridBalancingResourceTest

#### GET /GridBalancing - returns 200 with JSON list

Verifies the list endpoint returns HTTP 200 and a JSON array. The database starts empty so an empty array is expected.

#### POST /GridBalancing/recommend - responds with JSON

Triggers a recommendation cycle. Telemetry, UtilityOperator, and AssetLink services are unavailable (no WireMock in this class), so the endpoint returns HTTP 500 with a structured JSON error body. The test verifies the response is non-null JSON.

#### POST /GridBalancing/act/{id} - unknown ID returns 404

Calls `act` with recommendation ID 99999. Verifies HTTP 404 without needing any external service.

---

### GridBalancingActTest

All tests in this class seed the recommendation directly into the database and use WireMock stubs to control what the external services return. The WireMock server is reset before each test.

#### act - happy path: moves AssetLink and marks recommendation actioned

Setup:
- `/GridZone` returns two zones: `SURPLUS` (operator 1) and `DEFICIT` (operator 2).
- `/AssetLink` returns one link for prosumer 5 under operator 1 (the surplus zone).
- `DELETE /AssetLink/10` returns 204.
- `POST /AssetLink` returns 201 with `Location: /AssetLink/11`.

Verifications:
- Response is 200 with `movedProsumerId=5`, `fromZone=SURPLUS`, `toZone=DEFICIT`, `newAssetLink=/AssetLink/11`.
- The database record has `actioned=true` after the call.
- WireMock confirms `DELETE /AssetLink/10` and `POST /AssetLink` were actually called.

#### act - zone not found in GridZone response returns 404

GridZone returns a zone named `UNRELATED-ZONE`, which does not match the recommendation's `deficitZoneId` or `surplusZoneId`. Expects 404.

#### act - no AssetLink in surplus zone returns 404

GridZone resolves both zones correctly, but the only AssetLink belongs to operator 99 (not the surplus operator). The endpoint cannot find an AssetLink to move. Expects 404.
