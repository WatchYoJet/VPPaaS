# Prosumer API Documentation

This documentation describes the endpoints of the Prosumer microservice.

This API manages prosumer records, including creation, retrieval, update, and deletion.

<details>
<summary>Table of Contents</summary>

- [GET /Prosumer](#get-prosumer)
- [GET /Prosumer/{id}](#get-prosumerid)
- [POST /Prosumer](#post-prosumer)
- [PUT /Prosumer/{id}/{name}/{FiscalNumber}/{location}](#put-prosumeridfiscalnumberlocation)
- [DELETE /Prosumer/{id}](#delete-prosumerid)

</details>

## GET /Prosumer

Retrieves a list of all prosumers.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/Prosumer' \
>   -H 'accept: application/json'
> ```
>
> Replace `<KONG_HOST>` with the public DNS or IP address of the Kong EC2 instance.
>
> </details>

<br>

Returns a JSON array of prosumer objects:

```json
[
  {
    "id": <integer>,
    "name": <string>,
    "FiscalNumber": <integer>,
    "location": <string>
  }
]
```

## GET /Prosumer/{id}

Retrieves a single prosumer by ID. Replace `{id}` with the prosumer ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X GET \
>   'http://<KONG_HOST>:8000/Prosumer/1' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a single prosumer object, or `404 Not Found` if the ID does not exist:

```json
{
  "id": <integer>,
  "name": <string>,
  "FiscalNumber": <integer>,
  "location": <string>
}
```

## POST /Prosumer

Creates a new prosumer.

Must include a JSON body with the following fields:

```json
{
  "name": <string>,
  "FiscalNumber": <integer>,
  "location": <string>
}
```

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/Prosumer' \
>   -H 'Content-Type: application/json' \
>   -d '{
>     "name": "Alice",
>     "FiscalNumber": 123456789,
>     "location": "Lisbon"
>   }'
> ```
>
> </details>

<br>

Returns `201 Created` with a `Location` header pointing to the new resource (e.g., `/Prosumer/5`).

## PUT /Prosumer/{id}/{name}/{FiscalNumber}/{location}

Updates an existing prosumer. All fields are passed as path parameters.

No request body is required.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X PUT \
>   'http://<KONG_HOST>:8000/Prosumer/1/Alice/987654321/Porto'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.

## DELETE /Prosumer/{id}

Deletes a prosumer by ID. Replace `{id}` with the prosumer ID.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X DELETE \
>   'http://<KONG_HOST>:8000/Prosumer/1'
> ```
>
> </details>

<br>

Returns `204 No Content` on success, or `404 Not Found` if the ID does not exist.
