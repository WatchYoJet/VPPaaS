# Utility Operator API Documentation

This documentation describes the endpoints of the Utility Operator microservice.

This API manages utility operator records and their associated grid zones.

<details>
<summary>Table of Contents</summary>

- [GET /UtilityOperator](#get-utilityoperator)
- [GET /UtilityOperator/{id}](#get-utilityoperatorid)
- [POST /UtilityOperator](#post-utilityoperator)
- [PUT /UtilityOperator/{id}/{name}/{location}](#put-utilityoperatoridnamelocation)
- [DELETE /UtilityOperator/{id}](#delete-utilityoperatorid)
- [GET /GridZone](#get-gridzone)
- [GET /GridZone/{id}](#get-gridzoneid)
- [GET /GridZone/operator/{operatorId}](#get-gridzoneoperatoroperatorid)
- [POST /GridZone](#post-gridzone)
- [PUT /GridZone/{id}/{maxCapacity}/{boundaries}](#put-gridzoneidmaxcapacityboundaries)
- [DELETE /GridZone/{id}](#delete-gridzoneid)

</details>

---

## Utility Operator Endpoints

## GET /UtilityOperator

Retrieves a list of all utility operators.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/UtilityOperator' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON array of utility operator objects:

```json
[
  {
    "id": <integer>,
    "name": <string>,
    "location": <string>
  }
]
```

## GET /UtilityOperator/{id}

Retrieves a single utility operator by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/UtilityOperator/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a single utility operator object, or `404 Not Found` if the ID does not exist:

```json
{
  "id": <integer>,
  "name": <string>,
  "location": <string>
}
```

## POST /UtilityOperator

Creates a new utility operator.

Must include a JSON body with the following fields:

```json
{
  "name": <string>,
  "location": <string>
}
```

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/UtilityOperator' \
>   -H 'Content-Type: application/json' \
>   -d '{
>     "name": "EDP Lisbon",
>     "location": "Lisbon"
>   }'
> ```
>
> </details>

<br>

Returns `201 Created` with a `Location` header pointing to the new resource (e.g., `/UtilityOperator/3`).

## PUT /UtilityOperator/{id}/{name}/{location}

Updates an existing utility operator. All fields are passed as path parameters.

No request body is required.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X PUT \
>   'http://<KONG_HOST>:8000/UtilityOperator/1/EDP-Updated/Porto'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.

## DELETE /UtilityOperator/{id}

Deletes a utility operator by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X DELETE \
>   'http://<KONG_HOST>:8000/UtilityOperator/1'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.

---

## Grid Zone Endpoints

## GET /GridZone

Retrieves a list of all grid zones.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/GridZone' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON array of grid zone objects:

```json
[
  {
    "id": <integer>,
    "utilityOperatorId": <integer>,
    "name": <string>,
    "maxCapacity": <number>,
    "boundaries": <string>,
    "safetyThreshold": <number|null>,
    "postalCode": <string|null>
  }
]
```

`safetyThreshold` is the kW load level above which the zone is considered stressed. If `null`, the system defaults to 80% of `maxCapacity`. `postalCode` is used for neighbour detection in grid balancing.

## GET /GridZone/{id}

Retrieves a single grid zone by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/GridZone/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a single grid zone object, or `404 Not Found` if the ID does not exist.

## GET /GridZone/operator/{operatorId}

Retrieves all grid zones belonging to a specific utility operator.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/GridZone/operator/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON array of grid zone objects for the given operator.

## POST /GridZone

Creates a new grid zone under a utility operator.

Must include a JSON body with the following fields:

```json
{
  "utilityOperatorId": <integer>,
  "name": <string>,
  "maxCapacity": <number>,
  "boundaries": <string>,
  "safetyThreshold": <number|null>,
  "postalCode": <string|null>
}
```

`safetyThreshold` and `postalCode` are optional. If omitted, `safetyThreshold` defaults to 80% of `maxCapacity` at runtime.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/GridZone' \
>   -H 'Content-Type: application/json' \
>   -d '{
>     "utilityOperatorId": 1,
>     "name": "Zone-A",
>     "maxCapacity": 500.0,
>     "boundaries": "POLYGON((38.7 -9.1, 38.8 -9.1, 38.8 -9.0, 38.7 -9.0))",
>     "safetyThreshold": 400.0,
>     "postalCode": "1000"
>   }'
> ```
>
> </details>

<br>

Returns `201 Created` with a `Location` header pointing to the new resource (e.g., `/GridZone/2`).

## PUT /GridZone/{id}/{maxCapacity}/{boundaries}

Updates the capacity and boundaries of an existing grid zone. All fields are passed as path parameters.

No request body is required.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X PUT \
>   'http://<KONG_HOST>:8000/GridZone/1/600.0/POLYGON((38.7 -9.1, 38.8 -9.1, 38.8 -9.0, 38.7 -9.0))'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.

## DELETE /GridZone/{id}

Deletes a grid zone by ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X DELETE \
>   'http://<KONG_HOST>:8000/GridZone/1'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.
