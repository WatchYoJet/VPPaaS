# Prosumer Management

Two-pool collaboration process that handles prosumer creation through a negotiation handshake between an initiator (the prosumer side) and an executor (the manager side).

**Process IDs:** `ProsumerMngInitiator`, `ProsumerMngExecutor`

**Start from Tasklist:** Start `ProsumerMngInitiator`. The executor pool is started automatically via message.

---

## Flow

### Initiator pool

1. **Decide the Data for Prosumer Creation order:** fill in prosumer details.

   | Field | Key | Type |
   |-------|-----|------|
   | Name | `name` | text |
   | Fiscal Number | `fiscalnumber` | number |
   | Location | `location` | text |

2. A new `ProsumerMngExecutor` process instance is started automatically via the Camunda API. The executor receives the prosumer data.

3. Wait for the executor to respond:
   - **Promise received:** proceed to step 4.
   - **Decline received:** open **Decide what to do next** (`newrequest` checkbox).
     - `newrequest = true`: loop back to step 1.
     - `newrequest = false`: end.

4. **Check Prosumer Creation order:** review and decide whether to accept (`accept` checkbox).
   - `accept = true`: send acceptance to executor, wait for declare, then end.
   - `accept = false`: executor receives rejection and evaluates.

### Executor pool

1. **Verify if execute is possible:** review the submitted data (readonly) and decide (`promise` checkbox).
   - `promise = true`: send promise to initiator, then wait for reply.
   - `promise = false`: send decline to initiator, then end.

2. If initiator accepts:
   - **Create Prosumer:** `POST /Prosumer` via Kong.
   - Send declare to initiator, then end.

3. If initiator rejects:
   - **Evaluate arguments for rejection** (`reject` checkbox).
   - `reject = true`: send decline, then end.
   - `reject = false`: send decline, then end.

---

## Variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `name` | Initiator form | Prosumer name |
| `fiscalnumber` | Initiator form | Fiscal number |
| `location` | Initiator form | Location string |
| `accept` | Initiator check form | Whether initiator accepts the promise |
| `promise` | Executor form | Whether executor can proceed |
| `reject` | Executor form | Whether executor accepts the rejection arguments |
| `newrequest` | Initiator decline form | Whether to restart with new data |
| `prosumerID` | Create Prosumer response | ID of the created prosumer |
