# Asset Link Deletion

Single-pool, two-lane process for deleting an asset link. The executor reviews the request before the initiator confirms — the DELETE only fires after both approve. Deleting an asset link also removes the associated Kafka topic and stops the Telemetry consumer thread, so there is no reverting after the fact.

**Process ID:** `AssetLinkDeletion`

**Start from Tasklist:** Start `AssetLinkDeletion`.

---

## Flow

### Initiator lane

1. **Request Asset Link Deletion:** enter the ID of the asset link to delete.

   | Field | Key | Type |
   |-------|-----|------|
   | Asset Link ID | `assetLinkID` | number |

### Executor lane

2. **Verify if Asset Link Deletion is possible:** review the request and decide (`promise` checkbox).
   - `promise = false`: **Declined** end event — process ends, nothing deleted.
   - `promise = true`: hand back to initiator for final confirmation.

### Initiator lane

3. **Confirm Deletion order:** decide whether to proceed (`accept` checkbox).
   - `accept = false`: **Cancelled** end event — process ends, nothing deleted.
   - `accept = true`: hand to executor to execute the deletion.

### Executor lane

4. **Delete Asset Link** (service task): `DELETE /AssetLink/{assetLinkID}` via Kong. The AssetLink service also:
   - Looks up the utility operator name to reconstruct the Kafka topic (`{assetLinkID}-{operatorName}`).
   - Calls `AdminClient.deleteTopics` to remove the Kafka topic.
   - Calls `DELETE /Telemetry/Consume/{topicName}` to interrupt the consumer thread.
   - Deletes the AssetLink record from the database. Returns 204 on success.
5. **Declare Asset Link Deletion:** internal task that marks the process complete.
6. **Deleted** end event.

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `assetLinkID` | Initiator form | ID of the asset link to delete |
| `promise` | Executor form | Whether the executor approves the deletion |
| `accept` | Initiator confirm form | Whether the initiator confirms the order |
