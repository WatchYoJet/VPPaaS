# Energy Analytics

Triggers a server-side energy analytics computation and shows the timestamp of when it completed.

**Process ID:** `EnergyAnalytics`

**Start from Tasklist:** Start `EnergyAnalytics`.

---

## Flow

1. **Request Energy Analytics Computation:** confirm you want to trigger (`proceed` checkbox).

2. **Compute Energy Analytics** (service task): `POST /EnergyAnalytics/compute` via Kong.
   - Response: `{ "computed": true, "timestamp": "..." }`
   - Sets process variable `computedAt` from `httpResponse.body.timestamp`.

3. **Confirm Analytics Computed:** review the result.

   | Field | Key | Type | Notes |
   |-------|-----|------|-------|
   | Computed At | `computedAt` | text | Readonly, timestamp from the API |
   | Confirmed | `confirmed` | checkbox | |

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `proceed` | Request form | Trigger confirmation |
| `httpResponse` | HTTP connector | Full API response (body, status, headers) |
| `computedAt` | Output mapping | `httpResponse.body.timestamp` |
| `confirmed` | Confirm form | User acknowledgement |
