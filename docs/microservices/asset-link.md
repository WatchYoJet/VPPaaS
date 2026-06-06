# Asset Link API Documentation

This documentation describes the endpoints of the Asset Link microservice.

This API links prosumers to utility operators. On creation, it automatically provisions a dedicated Kafka topic and registers a consumer in the Telemetry service so that telemetry data for this link is ingested immediately.

<details>
<summary>Table of Contents</summary>

- [GET /AssetLink](#get-assetlink)
- [GET /AssetLink/{id}](#get-assetlinkid)
- [GET /AssetLink/{idProsumer}/{idUtilityOperator}](#get-assetlinkidprosumeridutilityoperator)
- [POST /AssetLink](#post-assetlink)
- [PUT /AssetLink/{id}/{idProsumer}/{idUtilityOperator}](#put-assetlinkididprosumeridutilityoperator)
- [DELETE /AssetLink/{id}](#delete-assetlinkid)

</details>

## GET /AssetLink

Retrieves a list of all asset links.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/AssetLink' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON array of asset link objects:

```json
[
  {
    "id": <integer>,
    "idProsumer": <integer>,
    "idUtilityOperator": <integer>
  }
]
```

## GET /AssetLink/{id}

Retrieves a single asset link by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/AssetLink/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a single asset link object, or `404 Not Found` if the ID does not exist.

## GET /AssetLink/{idProsumer}/{idUtilityOperator}

Retrieves the asset link for a specific prosumer and utility operator pair.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/AssetLink/1/2' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns the matching asset link object, or `404 Not Found` if no such link exists.

## POST /AssetLink

Creates a new asset link between a prosumer and a utility operator.

In addition to persisting the record, this endpoint:
1. Creates a Kafka topic named `{assetLinkId}-{utilityOperatorName}` (e.g. `1-EDP`).
2. Registers a new consumer thread in the Telemetry service for that topic.

Must include a JSON body with the following fields:

```json
{
  "idProsumer": <integer>,
  "idUtilityOperator": <integer>
}
```

The combination of `idProsumer` and `idUtilityOperator` must be unique.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/AssetLink' \
>   -H 'Content-Type: application/json' \
>   -d '{
>     "idProsumer": 1,
>     "idUtilityOperator": 2
>   }'
> ```
>
> </details>

<br>

Returns `201 Created` with a `Location` header pointing to the new resource (e.g., `/AssetLink/3`).

## PUT /AssetLink/{id}/{idProsumer}/{idUtilityOperator}

Updates the prosumer and utility operator of an existing asset link. All fields are passed as path parameters.

No request body is required.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X PUT \
>   'http://<KONG_HOST>:8000/AssetLink/1/2/3'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.

## DELETE /AssetLink/{id}

Deletes an asset link by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X DELETE \
>   'http://<KONG_HOST>:8000/AssetLink/1'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.
