# Telemetry API Documentation

This documentation describes the endpoints of the Telemetry microservice.

This API stores asset telemetry readings consumed from Kafka topics and exposes them for querying by other microservices. Each asset type populates only its relevant fields; unused fields are stored as `NULL`.

<details>
<summary>Table of Contents</summary>

- [GET /Telemetry](#get-telemetry)
- [GET /Telemetry/{id}](#get-telemetryid)
- [POST /Telemetry/Consume](#post-telemetryconsume)

</details>

## GET /Telemetry

Retrieves all telemetry records.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/Telemetry' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON array of telemetry records. Fields that are not applicable to an asset type will be `null`.

```json
[
  {
    "id": <integer>,
    "timeStamp": <string>,
    "asset_id": <integer>,
    "asset_type": "BATTERY" | "SOLAR" | "EV_CHARGER",
    "grid_cell_id": <string>,
    "State_of_Charge": <number|null>,
    "Available_Energy": <number|null>,
    "Current_Output": <number|null>,
    "Max_Capacity": <number|null>,
    "State_of_Health": <number|null>,
    "Status": <string|null>,
    "Current_Generation": <number|null>,
    "Daily_Total": <number|null>,
    "Grid_Voltage": <number|null>,
    "Frequency": <number|null>,
    "Plug_Status": <string|null>,
    "Charging_Rate": <number|null>,
    "Session_Energy": <number|null>,
    "EV_SoC": <number|null>
  }
]
```

Asset-type field mapping:

| Asset type | Relevant fields |
|---|---|
| `BATTERY` | `State_of_Charge`, `Available_Energy`, `Current_Output`, `Max_Capacity`, `State_of_Health`, `Status` |
| `SOLAR` | `Current_Generation`, `Daily_Total`, `Grid_Voltage`, `Frequency` |
| `EV_CHARGER` | `Plug_Status`, `Charging_Rate`, `Session_Energy`, `EV_SoC` |

## GET /Telemetry/{id}

Retrieves a single telemetry record by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/Telemetry/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a single telemetry record, or `404 Not Found` if the ID does not exist.

## POST /Telemetry/Consume

Registers a new Kafka topic consumer for telemetry ingestion. This endpoint is called automatically by the Asset Link service on asset link creation and does not need to be called manually.

Must include a JSON body with the topic name:

```json
{
  "TopicName": <string>
}
```

The topic name format is `{assetLinkId}-{utilityOperatorName}` (e.g. `1-EDP`).

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/Telemetry/Consume' \
>   -H 'Content-Type: application/json' \
>   -d '{"TopicName": "1-EDP"}'
> ```
>
> </details>

<br>

Returns a plain text confirmation: `New worker started`.

A background `DynamicTopicConsumer` thread is started that continuously reads from the given Kafka topic and inserts records into the `Telemetry` table.
