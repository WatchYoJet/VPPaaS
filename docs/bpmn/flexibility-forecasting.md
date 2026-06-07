# Flexibility Forecasting

Requests an AI-generated flexibility forecast from Ollama (llama3.2) and lets the operator approve or reject it.

**Process ID:** `FlexibilityForecasting`

**Start from Tasklist:** Start `FlexibilityForecasting`.

> The AI call can take up to 3 minutes; the connector read timeout is set to 180 s.

---

## Flow

1. **Request Flexibility Forecast:** confirm you want to trigger (`proceed` checkbox).

2. **Generate AI Forecast** (service task): `POST /FlexibilityForecasting/forecast` via Kong.
   - Response: `{ "forecast": "..." }`
   - Sets process variable `forecastText` from `httpResponse.body.forecast`.

3. **Review Forecast Results:** read the forecast and decide.

   | Field | Key | Type | Notes |
   |-------|-----|------|-------|
   | Forecast | `forecastText` | textarea | Readonly, AI-generated text |
   | Approve forecast | `approved` | checkbox | |

4. Gateway on `approved`:
   - `approved = true`: Forecast Approved end event.
   - `approved = false`: Forecast Rejected end event.

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `proceed` | Request form | Trigger confirmation |
| `httpResponse` | HTTP connector | Full API response (body, status, headers) |
| `forecastText` | Output mapping | `httpResponse.body.forecast` |
| `approved` | Review form | Whether the operator approves the forecast |
