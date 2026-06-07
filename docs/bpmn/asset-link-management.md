# Asset Link Management

Three-pool collaboration that links a prosumer to a utility operator and provisions the corresponding Kafka telemetry topic. The three pools communicate through messages.

**Process IDs:** `ProsumerForAssetLink`, `AssetLinkManagement`, `TelemetryManagement`

**Start from Tasklist:** Start `ProsumerForAssetLink`. The other two pools start automatically via messages.

> `AssetLinkManagement` and `TelemetryManagement` both have Message Start Events; they cannot be started directly from Tasklist.

---

## Flow

### ProsumerForAssetLink pool (Initiator)

1. Fetch prosumer and utility operator lists from Kong in parallel:
   - `GET /Prosumer` (stored as `ProsumerList`)
   - `GET /UtilityOperator` (stored as `UtilityOperatorList`)

2. **Decide the data to AssetLink association order:** select the prosumer and operator.

   | Field | Key | Type |
   |-------|-----|------|
   | Utility Operator | `UtilityOperatorID` | select (from `UtilityOperatorList`) |
   | Prosumer | `prosumerID` | select (from `ProsumerList`) |

3. Send message to start `AssetLinkManagement` with the selected IDs.

4. Wait for the executor to respond:
   - **Promise received:** open **Check AssetLink association order** (`accept` checkbox).
     - `accept = true`: send acceptance, wait for declare, then end.
     - `accept = false`: end.
   - **Decline received:** end.

### AssetLinkManagement pool (Executor)

1. **Verify if execute product is possible:** review IDs (readonly) and decide (`promise` checkbox).
   - `promise = false`: send decline, then end.
   - `promise = true`: send promise, then wait for initiator reply.

2. If accepted:
   - **Associate AssetLink:** `POST /AssetLink` with `{idProsumer, idUtilityOperator}`.
   - **Retrieve AssetID:** `GET /AssetLink/{prosumerID}/{UtilityOperatorID}`.
   - **Retrieve UtilityOperatorName:** `GET /UtilityOperator/{UtilityOperatorID}`.
   - Send declare to initiator and message to start `TelemetryManagement`, then end.

### TelemetryManagement pool

Starts automatically when AssetLinkManagement declares success. Provisions the Kafka topic for the new asset link (handled internally by the Telemetry service).

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `prosumerID` | Initiator form | Selected prosumer ID |
| `UtilityOperatorID` | Initiator form | Selected utility operator ID |
| `ProsumerList` | GET /Prosumer | List for the form dropdown |
| `UtilityOperatorList` | GET /UtilityOperator | List for the form dropdown |
| `promise` | Executor form | Whether executor can proceed |
| `accept` | Initiator check form | Whether initiator accepts |
| `assetLinkID` | GET /AssetLink response | ID of the created asset link |
| `UtilityOperatorName` | GET /UtilityOperator response | Name of the utility operator |
