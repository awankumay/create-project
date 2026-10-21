# Working agreement

Read README.md and docs/OFFLINE.md before changing sync behavior. Maintain atomic local draft+outbox writes, server draft+receipt writes, and local pull+cursor writes. Never regenerate IDs on retries. Enforce ownership server-side and keep data partitioned by server+account locally.

Run backend OfflineDraftSyncTest and Flutter offline_sync_test.dart after sync changes. Test lost responses, restart, account changes, duplicate requests and conflicts. Do not enable edits, deletes, payment confirmation or inventory guarantees without explicit business policies and tests. Do not claim production RBAC or database encryption exists.
