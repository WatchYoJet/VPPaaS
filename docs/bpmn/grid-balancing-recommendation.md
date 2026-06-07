# Grid Balancing Recommendation

Triggers a grid balancing recommendation computation, lets the operator review and accept a recommendation, and executes the rebalancing action by moving a prosumer's AssetLink from the surplus zone to the deficit zone.

**Process ID:** `GridBalancingRecommendation`

**Start from Tasklist:** Start `GridBalancingRecommendation`.

---

## Flow

1. **Request Grid Balancing Recommendation:** confirm you want to trigger (`proceed` checkbox).

2. **Generate Grid Balancing Recommendation** (service task): `POST /GridBalancing/recommend` via Kong. Computes net load per zone using telemetry (EV chargers increase load, battery discharge and solar generation reduce it), identifies zones exceeding their safety threshold, and pairs them with neighbouring surplus zones (consecutive postal codes). Returns a list of recommendations.

3. **Review Recommendations:** read the recommendations list, enter the `selectedRecommendationId` of the one to act on, and check `accept` to proceed or uncheck to reject.

4. Gateway on `accept`:
   - `accept = true`: proceed to execution.
   - `accept = false`: Recommendation Rejected end event.

5. **Act on Recommendation** (service task): `POST /GridBalancing/act/{selectedRecommendationId}` via Kong. Finds an AssetLink in the surplus zone, deletes it (removes the Kafka topic and stops the Telemetry consumer), creates a new AssetLink for the same prosumer in the deficit zone (registers a new Kafka topic and Telemetry consumer), and marks the recommendation as actioned.

6. **Confirm Action Executed:** acknowledge completion (`confirmed` checkbox), then end.

---

## Variables

| Variable | Direction | Set by | Description |
|----------|-----------|--------|-------------|
| `proceed` | Input | Request form | Trigger confirmation |
| `recommendations` | Process | Generate service task | JSON string of recommendations (id, deficitZoneId, surplusZoneId, recommendedActionKw, timestamp) |
| `selectedRecommendationId` | Input | Review form | DB id of the chosen recommendation |
| `accept` | Input | Review form | `true` to execute, `false` to reject |
| `confirmed` | Input | Confirm form | Operator acknowledgement after execution |

---

## What the system changes

When the operator accepts a recommendation, the system:
1. Removes the AssetLink connecting the surplus-zone prosumer to its current utility operator (deletes the Kafka topic `{assetLinkId}-{operatorName}` and stops the Telemetry consumer thread).
2. Creates a new AssetLink for the same prosumer linked to the deficit zone's utility operator (creates a new Kafka topic and registers a new Telemetry consumer).

The prosumer's assets (batteries, solar, EV chargers) now contribute telemetry and capacity to the deficit zone, moving the grid toward balance.
