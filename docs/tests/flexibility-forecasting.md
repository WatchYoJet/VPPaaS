# Flexibility Forecasting Tests

Unit tests for the Flexibility Forecasting microservice using QuarkusTest and RestAssured.

Note: `POST /FlexibilityForecasting/forecast` calls the Flexibility Event service and Ollama, both of which are unavailable in the test environment. The service falls back to a generic prompt when the Flexibility Event service is unreachable, then fails on the Ollama call and returns a structured JSON error response.

## How to run

```bash
mvn test -pl microservices/FlexibilityForecasting
```

## Test cases

### POST /FlexibilityForecasting/forecast — responds with JSON

Triggers a forecast request. Because Ollama is unreachable in the test environment, the endpoint returns HTTP 500 with a structured JSON error body. The test verifies the response is JSON and is not null.
