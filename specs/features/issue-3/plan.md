# Feature: Ops Data Decryptor (Issue 3)

## Plan
1. **scheduler/mitm_scheduler/internal/db**: Create a method `GetActiveStorageKeys(ctx context.Context) ([]string, error)` that queries both `storage_keys` (where is_active = true) and `user_roles_encrypted`. It should return a list of all unique wrapped keys (base64 encoded).
2. **scheduler/mitm_scheduler/internal/http**: Add `handleGetStorageKeys(w http.ResponseWriter, r *http.Request)` in `server.go` (or `server_keys.go`) that calls the DB method and returns a JSON array of keys.
3. **scheduler/mitm_scheduler/internal/http/server.go**: Register the endpoint `mux.HandleFunc("/admin/storage-keys", s.handleGetStorageKeys)` protected by RBAC (same as other `/admin/` routes).

## Tasks
- [ ] Task 1: Add `GetActiveStorageKeys` to the DB layer.
- [ ] Task 2: Add HTTP handler and register the `/admin/storage-keys` route.
