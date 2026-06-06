# Flexibility Forecasting API Documentation

This documentation describes the endpoints of the Flexibility Forecasting microservice.

This API generates AI-based flexibility forecasts by retrieving recent flexibility events and sending them as context to an Ollama LLM instance running `llama3.2`. The response is returned directly to the caller and is not persisted or published to Kafka.

<details>
<summary>Table of Contents</summary>

- [POST /FlexibilityForecasting/forecast](#post-flexibilityforecastingforecast)

</details>

## POST /FlexibilityForecasting/forecast

Generates a flexibility forecast. The service fetches the last 5 flexibility events from the Flexibility Event service, builds a prompt, and sends it to Ollama. If the Flexibility Event service is unreachable, a generic VPP forecast prompt is used instead.

No payload is required for this endpoint.

> <details>
> <summary>Curl Example</summary>
>
> ```bash
> curl -X POST \
>   'http://<KONG_HOST>:8000/FlexibilityForecasting/forecast' \
>   -H 'accept: application/json'
> ```
>
> </details>

<br>

Returns a JSON object containing the LLM-generated forecast text:

```json
{
  "forecast": <string>
}
```

Note: This endpoint may take up to 3 minutes to respond, depending on model load on the Ollama instance. The LLM model used is `llama3.2` with a maximum output of 150 tokens.
