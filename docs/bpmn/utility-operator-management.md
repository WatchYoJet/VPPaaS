# Utility Operator Management

Single-pool, two-lane process for creating a utility operator. Simpler than the Prosumer flow with no message-based negotiation, just a sequential handoff between lanes.

**Process ID:** `UtilityOperatorManagement`

**Start from Tasklist:** Start `UtilityOperatorManagement`.

---

## Flow

### Initiator lane

1. **Request Utility Operator Creation:** fill in operator details.

   | Field | Key | Type |
   |-------|-----|------|
   | Name | `name` | text |
   | Location | `location` | text |

### Executor lane

2. **Verify if Utility Operator Creation is possible:** review submitted data (readonly) and decide (`promise` checkbox).
   - `promise = true`: run **Create Utility Operator** (`POST /UtilityOperator` via Kong), then end.
   - `promise = false`: end.

### Initiator lane

3. **Check Utility Operator Creation:** confirm the result (`accept` checkbox), then end.

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `name` | Initiator form | Operator name |
| `location` | Initiator form | Location string |
| `promise` | Executor form | Whether the executor can proceed |
| `accept` | Initiator confirm form | Initiator acknowledgement |
