# Offline protocol v1

## Invariants

- Each draft is immutable. Its UUID and operation UUID are created on the client.
- Draft + outbox entry are written atomically in local SQLite.
- Scope is normalized server origin + authenticated user ID. Tokens are stored in OS secure storage; local rows never contain passwords or tokens.
- The server assigns owner from Sanctum, ignoring any client owner claim.
- A successful push means both server draft and idempotency receipt committed in one transaction. Repeating the same operation returns the same result; changed content with that operation returns 409.
- The client clears an outbox entry only after a matching acknowledgement. Losing the HTTP response leaves it safe to retry.
- Local error states survive restart. 401 pauses sending until reauthentication; 408/429/network/5xx retry with persisted exponential delay. 403/409/422 remain visible as rejected until reviewed.
- Pull is user-scoped and append-only; rows and cursor are committed together on the client. Pending local records are not acknowledged by pull.
- Writes are serialized on the user row on MySQL to avoid commit-order gaps behind a per-user cursor. All future writers must follow that invariant; direct SQL/admin inserts bypassing the service are unsupported.

## Deliberate scope

No edit, delete, tombstones, inventory guarantees, offline QRIS verification, accounting, multi-company data scopes or multi-level roles are implemented. Add a version/conflict policy and tombstone retention BEFORE enabling editable/deletable offline records. Do not apply last-write-wins to financial records.

Sync runs in the foreground only. Realtime notifications, if later added, are hints to pull; they cannot replace a durable outbox or cursor. A reachable Wi-Fi connection is not proof the API is reachable.

## Deployment

Start with one local Laravel server per installation for LAN operation. Internet outages do not affect clients still able to reach this server. Per-device offline storage covers actual server/network unavailability. Branch-to-central replication is a different feature and is not included.

Goravel may later host a hardware/protocol gateway. It is not required for this sync protocol; do not split ownership of ERP business rules across Laravel and Goravel.
