# Utility Operator Deletion

Single-pool, two-lane process for deleting a utility operator. The executor reviews the request before the initiator confirms — the DELETE only fires after both approve, so there is no reverting after the fact.

**Process ID:** `UtilityOperatorDeletion`

**Start from Tasklist:** Start `UtilityOperatorDeletion`.

---

## Flow

### Initiator lane

1. **Request Utility Operator Deletion:** enter the ID of the operator to delete.

   | Field | Key | Type |
   |-------|-----|------|
   | Utility Operator ID | `utilityOperatorID` | number |

### Executor lane

2. **Verify if Utility Operator Deletion is possible:** review the request and decide (`promise` checkbox).
   - `promise = false`: **Declined** end event — process ends, nothing deleted.
   - `promise = true`: hand back to initiator for final confirmation.

### Initiator lane

3. **Confirm Deletion order:** decide whether to proceed (`accept` checkbox).
   - `accept = false`: **Cancelled** end event — process ends, nothing deleted.
   - `accept = true`: hand to executor to execute the deletion.

### Executor lane

4. **Delete Utility Operator** (service task): `DELETE /UtilityOperator/{utilityOperatorID}` via Kong. Returns 204 on success.
5. **Declare Utility Operator Deletion:** internal task that marks the process complete.
6. **Deleted** end event.

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `utilityOperatorID` | Initiator form | ID of the utility operator to delete |
| `promise` | Executor form | Whether the executor approves the deletion |
| `accept` | Initiator confirm form | Whether the initiator confirms the order |
