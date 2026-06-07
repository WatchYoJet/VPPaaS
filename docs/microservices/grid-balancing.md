# Grid Balancing API Documentation

This documentation describes the endpoints of the Grid Balancing microservice.

This API analyses current grid conditions across all zones and produces recommendations to transfer energy from surplus zones to deficit zones. Recommendations are persisted in the database and published to the `grid-balancing-recommendation` Kafka topic.

The algorithm:
1. Computes net grid load per zone: `net_load = EV_Charging_Rate - Battery_Current_Output - Solar_Current_Generation`. A positive value means the zone is net-importing (stressed); a negative value means it has surplus.
2. Excludes batteries with State of Charge below 20% or with status `OFFLINE`, `FAULT`, or `MAINTENANCE`.
3. Marks a zone as a deficit zone if its `net_load` exceeds its `safetyThreshold` (defaults to 80% of `maxCapacity` if not set).
4. Pairs it with a surplus zone whose `net_load` is below 50% of its threshold and whose postal code differs by at most 1 digit.
5. Recommends transferring enough energy to bring the deficit zone down to 70% of its threshold.

This endpoint is also triggered automatically whenever an `energy-discharged-by-zone` Kafka message is received.

<details>
<summary>Table of Contents</summary>

- [GET /GridBalancing](#get-gridbalancing)
- [POST /GridBalancing/recommend](#post-gridbalancingrecommend)
- [POST /GridBalancing/act/{id}](#post-gridbalancingactid)

</details>

## GET /GridBalancing

Retrieves all stored grid balancing recommendations.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/GridBalancing' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON array of recommendation records:

```json
[
  {
    "id": <integer>,
    "deficitZoneId": <string>,
    "surplusZoneId": <string>,
    "recommendedActionKw": <number>,
    "timestamp": <string>,
    "actioned": <boolean>
  }
]
```

`actioned` is `false` until the recommendation is executed via `POST /GridBalancing/act/{id}`, after which it becomes `true`.

## POST /GridBalancing/recommend

Triggers a grid balancing analysis. Fetches telemetry, grid zone configuration, and asset links, then runs the balancing algorithm. Each recommendation found is persisted and published to Kafka.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/GridBalancing/recommend' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON object with the list of recommendations generated in this cycle:

```json
{
  "recommendations": [
    {
      "id": <integer>,
      "deficitZoneId": <string>,
      "surplusZoneId": <string>,
      "recommendedActionKw": <number>,
      "timestamp": <string>
    }
  ]
}
```

Each recommendation includes its database `id`, which is the value to pass to `POST /GridBalancing/act/{id}` to execute it. An empty `recommendations` array means no zone pairs met the balancing criteria at the time of the request.

## POST /GridBalancing/act/{id}

Executes a previously generated recommendation by physically moving a prosumer's AssetLink from the surplus zone to the deficit zone.

The endpoint:
1. Loads the recommendation by `id` to get the surplus and deficit zone names.
2. Finds the GridZone records to resolve the utility operator IDs for each zone.
3. Finds the first AssetLink whose utility operator is in the surplus zone.
4. Deletes that AssetLink (which removes the Kafka topic and stops the Telemetry consumer thread).
5. Creates a new AssetLink for the same prosumer linked to the deficit zone's utility operator (which creates a new Kafka topic and starts a new Telemetry consumer thread).
6. Marks the recommendation as `actioned = true`.

No payload is required. The recommendation `id` is passed as a path parameter.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/GridBalancing/act/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns `200 OK` with a JSON summary of the action performed:

```json
{
  "recommendationId": <integer>,
  "movedProsumerId": <integer>,
  "fromZone": <string>,
  "toZone": <string>,
  "newAssetLink": <string>
}
```

Returns `404 Not Found` if the recommendation ID does not exist, if a zone named in the recommendation is not found, or if there is no AssetLink in the surplus zone to move.
