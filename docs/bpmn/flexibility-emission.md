# Flexibility Emission

Triggers flexibility event evaluation and shows how many events were processed.

**Process ID:** `FlexibilityEmission`

**Start from Tasklist:** Start `FlexibilityEmission`.

---

## Flow

1. **Request Flexibility Event Emission:** confirm you want to trigger (`proceed` checkbox).

2. **Trigger Flexibility Events** (service task): `POST /FlexibilityEvent/trigger` via Kong.
   - Response: `{ "processed": N, "events": [...] }`
   - Sets process variable `eventsProcessed` from `httpResponse.body.processed`.

3. **Confirm Events Emitted:** review the result.

   | Field | Key | Type | Notes |
   |-------|-----|------|-------|
   | Events Processed | `eventsProcessed` | number | Readonly, count from the API |
   | Confirmed | `confirmed` | checkbox | |

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `proceed` | Request form | Trigger confirmation |
| `httpResponse` | HTTP connector | Full API response (body, status, headers) |
| `eventsProcessed` | Output mapping | `httpResponse.body.processed` |
| `confirmed` | Confirm form | User acknowledgement |
