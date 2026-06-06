# Flexibility Event API Documentation

This documentation describes the endpoints of the Flexibility Event microservice.

This API evaluates current telemetry data against business rules to generate flexibility events. Events are persisted in the database and published to the `flexibility-offers` Kafka topic.

<details>
<summary>Table of Contents</summary>

- [GET /FlexibilityEvent](#get-flexibilityevent)
- [GET /FlexibilityEvent/{id}](#get-flexibilityeventid)
- [POST /FlexibilityEvent/trigger](#post-flexibilityeventtrigger)

</details>

## GET /FlexibilityEvent

Retrieves all stored flexibility events.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/FlexibilityEvent' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON array of flexibility event objects:

```json
[
  {
    "id": <integer>,
    "assetLinkId": <integer>,
    "gridCellId": <string>,
    "eventType": <string>,
    "incentiveValue": <number>,
    "timestamp": <string>
  }
]
```

Possible `eventType` values:

| eventType | Trigger condition | incentiveValue |
|---|---|---|
| `SELL` | Battery SoC > 90% during peak hours (08:00-10:00 or 18:00-21:00) | 15.0 |
| `UNAVAILABLE` | Battery SoC < 20% | 0.0 |
| `EMERGENCY_DISCHARGE` | Solar grid frequency < 49.8 Hz | 0.0 |
| `OVERVOLTAGE_WARNING` | Solar grid voltage > 253 V | 0.0 |

## GET /FlexibilityEvent/{id}

Retrieves a single flexibility event by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/FlexibilityEvent/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a single flexibility event object, or `404 Not Found` if the ID does not exist.

## POST /FlexibilityEvent/trigger

Triggers a flexibility analysis cycle. Fetches the latest telemetry, evaluates business rules for each asset, and for every rule match: persists the event and publishes it to the `flexibility-offers` Kafka topic.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/FlexibilityEvent/trigger' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON object with the number of events generated and their details:

```json
{
  "processed": <integer>,
  "events": [
    {
      "assetLinkId": <integer>,
      "gridCellId": <string>,
      "eventType": <string>,
      "incentiveValue": <number>,
      "timestamp": <string>
    }
  ]
}
```
