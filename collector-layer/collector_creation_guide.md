# Developer Guide: Creating a Data Ingestion Collector

This guide describes how to implement a new data collector in the **Man-in-the-Middle (MitM) Data Aggregator** system. Collectors are autonomous, standalone Go binaries that are executed by the scheduler to pull raw data from a source system, encrypt it, and write it to the central database landing zone.

The reference implementation is the Oracle collector [`./mitm_collector_ora/main.go`](./mitm_collector_ora/main.go). The counterpart that starts and supervises collectors is the Scheduler Server [`/core-layer/mitm_scheduler-server`](../core-layer/mitm_scheduler-server/src/job_runner.rs). The concepts behind both are described in [`./collector_concept.md`](./collector_concept.md).

---

## 1. Core Principles & Requirements

Every collector must adhere to the following design standards:

- **Standalone Go Binary:** Build the collector as an independent Go program with its own `go.mod`. Do not couple it directly to the scheduler module tree.
- **Envelope Encryption First:** All data written to the `raw_ingestion` landing zone must be encrypted with AES-GCM (12-byte random nonce) using a Data Encryption Key (DEK) retrieved from the target database.
- **Credentials via IPC:** The Master Key (KEK) and the MitM database credentials are fetched via IPC from the scheduler at process startup. Environment variables are only a fallback for standalone execution.
- **State Preservation (Cursors):** Query the source incrementally using state-based cursors (e.g. tracking auto-incrementing IDs or modification timestamps) stored in `ingestion_cursors`.
- **Atomic Ingestion:** Inserts into `raw_ingestion` and the corresponding cursor progression in `ingestion_cursors` must be committed in the same database transaction.
- **Safe Dynamic SQL:** Table and column identifiers used in dynamic SQL must be validated against `^[a-zA-Z0-9_]+$` (or database metadata). Values are always passed as bound parameters.
- **Nil-Safe IPC Logging:** Communicate execution progress and audit events back to the parent scheduler over a Unix Domain Socket if the environment variables are present. The IPC client must be nil-safe to allow standalone CLI execution for debugging.
- **Logging Separation:** `system_logs` for lifecycle/errors, `job_audit_logs` for processing metrics, `admin_audit_logs` for manual triggers/config changes. Collectors do not write log tables directly; the scheduler stores their IPC `status` events in `job_status_events` and their `audit` events in `job_audit_logs`.
- **Standardized SPDX Headers:** Every source file must include the standardized Apache-2.0 SPDX header at the top.

---

## 2. Bootstrapping & Configuration Inputs

A collector receives its configuration from three places:

1. **Scheduler IPC (Preferred):** When `RUN_ID` and `SCHEDULER_SOCKET_PATH` are set, the collector requests the MitM database config and the `MASTER_KEY` via `get_credentials` (see [Section 4](#4-nil-safe-ipc-client-implementation)).
2. **Environment Variables (Fallback):** `MITM_DB_CONFIG_JSON` or the individual `MITM_DB_*` variables plus `MASTER_KEY` (see [Section 3](#3-environment-variables)).
3. **`os.Args[1]` (Optional):** A single JSON string containing job-specific overrides (e.g. table name, source name, cursor column, topic).

### Registering the Job in the Scheduler

The scheduler starts a collector from its `scheduled_programs` entry:

```sql
INSERT INTO scheduled_programs (name, command, args, cron_expr, enabled, restart_on_exit)
VALUES (
  'ora_employees',
  'mitm-collector-ora',                     -- resolved relative to the scheduler binary's directory
  '{"source_name": "ORA_EMPLOYEE", "table": "EMPLOYEES", "cursor_column": "ID",
    "topic": "employee.data", "business_key_column": "EMPLOYEE_ID"}'::jsonb,
  '*/15 * * * *',                           -- 5-field cron (seconds/year are added); 6/7-field passed through
  true,
  false
);
```

- The binary must be located next to the scheduler binary (`app/bin/`); this is also the working directory of the run.
- `args` is passed verbatim as `os.Args[1]`. Under the scheduler `os.Args[1]` is therefore always present (`{}` if `args` is empty).
- The same job is never started twice in parallel; a trigger while it is still running is skipped.

### TargetDBConfig Struct

Holds the connection parameters of the central MitM target database:

```go
type TargetDBConfig struct {
	Host       string `json:"host"`
	Port       int    `json:"port"`
	User       string `json:"user"`
	Password   string `json:"password"`
	Database   string `json:"database"`
	DSN        string `json:"dsn"`
	SourceName string `json:"source_name"`
}
```

`MITM_DB_CONFIG_JSON` (and the `db_config_json` delivered via IPC) uses a nested `"db"` object; `sslmode` is a boolean. The IPC variant is the scheduler's complete serialized configuration (it also contains fields such as `log_level`, `socket_dir`, `db.max_conns`); parse only the `db` object and ignore the rest:

```go
var fullCfg struct {
	DB struct {
		Host     string `json:"host"`
		Port     int    `json:"port"`
		User     string `json:"user"`
		Password string `json:"password"`
		Database string `json:"database"`
		SSLMode  bool   `json:"sslmode"`
	} `json:"db"`
}
```

`sslmode: true` maps to `sslmode=require`, `false` to `sslmode=disable`.

### SourceDBConfig Struct

Holds the decrypted connection parameters of the source system (contents of `source_credentials.config_payload`). For SQL sources:

```go
type SourceDBConfig struct {
	Host     string `json:"host"`
	Port     int    `json:"port"`
	User     string `json:"user"`
	Password string `json:"password"`
	Database string `json:"database"`
	Service  string `json:"service"`
	SID      string `json:"sid"`
	DSN      string `json:"dsn"`
}
```

### Job Overrides Struct

Define the structure for parsing the optional `os.Args[1]` (job configuration):

```go
type CollectorArgs struct {
	SourceName        string              `json:"source_name"`
	Table             string              `json:"table"`
	CursorColumn      string              `json:"cursor_column"`       // "none" disables incremental mode
	Topic             string              `json:"topic"`               // Target routing topic
	BusinessKeyColumn string              `json:"business_key_column"` // Source of the correlation_id
	DBWhereIn         map[string][]string `json:"db_where_in,omitempty"`
}
```

Example:

```json
{
  "source_name": "ORA_EMPLOYEE",
  "table": "EMPLOYEES",
  "cursor_column": "ID",
  "topic": "employee.data",
  "business_key_column": "EMPLOYEE_ID",
  "db_where_in": { "DEPARTMENT": ["IT", "HR"] }
}
```

Defaults and rules in the reference implementation:

- `table` defaults to `employees` and must match the identifier regex. Setting `table` without `topic` derives the topic as `ora.<table lowercase>.data`.
- `cursor_column` has no default. Without it (or with `"none"`), the full table is read and no cursor is stored.
- `business_key_column` defaults to `id`.
- Every key in `db_where_in` must match the identifier regex; empty value lists are ignored.
- An unparsable `os.Args[1]` is logged as a warning and the defaults are used.

---

## 3. Environment Variables

The scheduler starts every collector with a **cleared environment**. Only `PATH`, `SYSTEMROOT`, `USERPROFILE`, `HOME`, `TEMP`, `TMP` and all variables starting with `MITM_` are inherited; `RUN_ID` and `SCHEDULER_SOCKET_PATH` are added. Any other variable a collector needs must therefore be named `MITM_*` or be passed via `args`.

- **`RUN_ID` (Optional):** The run instance ID injected by the scheduler (`program_runs.id`).
- **`SCHEDULER_SOCKET_PATH` (Optional):** The file path to the Unix Domain Socket of the scheduler (`<socket_dir>/mitm_scheduler.sock`).
- **`MASTER_KEY` (Required for standalone):** The 32-byte Master Key (KEK), base64-encoded or as 32 raw bytes. It is **not** inherited from the scheduler's environment; under the scheduler it is only available via IPC.
- **`MITM_DB_CONFIG_JSON` (Fallback, preferred over single variables):** JSON with a nested `"db"` object (see above).
- **`MITM_DB_HOST`, `MITM_DB_PORT`, `MITM_DB_USER`, `MITM_DB_PASSWORD`, `MITM_DB_NAME` (Fallback):** Individual connection parameters of the MitM target database.
- **`MITM_DB_SSLMODE` (Optional):** `true` → `require`, `false` → `disable`; any other value (e.g. `verify-full`) is passed through as PostgreSQL `sslmode`. Default: `disable`.

Validate the KEK before use:

```go
func validateKEK(masterKey string) ([]byte, error) {
	if masterKey == "" {
		return nil, fmt.Errorf("Missing MASTER_KEY environment variable")
	}

	var kek []byte
	if decoded, err := base64.StdEncoding.DecodeString(masterKey); err == nil && len(decoded) == 32 {
		kek = decoded
	} else {
		kek = []byte(masterKey)
	}

	if len(kek) != 32 {
		return nil, fmt.Errorf("MASTER_KEY must be exactly 32 bytes, got %d", len(kek))
	}
	return kek, nil
}
```

---

## 4. Nil-Safe IPC Client Implementation

### Credential Request

As the very first step in `main()`, request the credentials from the scheduler and expose them as environment variables, so the rest of the bootstrapping works identically under the scheduler and standalone:

```go
func fetchCredentialsFromScheduler() (string, string, error) {
	runIDStr := os.Getenv("RUN_ID")
	socketPath := os.Getenv("SCHEDULER_SOCKET_PATH")
	if runIDStr == "" || socketPath == "" {
		return "", "", fmt.Errorf("not running under scheduler")
	}

	runID, err := strconv.Atoi(runIDStr)
	if err != nil {
		return "", "", err
	}

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return "", "", err
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(5 * time.Second))

	req := map[string]interface{}{
		"type":   "get_credentials",
		"run_id": runID,
	}
	data, _ := json.Marshal(req)
	if _, err := conn.Write(append(data, '\n')); err != nil {
		return "", "", err
	}

	scanner := bufio.NewScanner(conn)
	if scanner.Scan() {
		var resp struct {
			MasterKey    string `json:"master_key"`
			DBConfigJSON string `json:"db_config_json"`
		}
		if err := json.Unmarshal(scanner.Bytes(), &resp); err == nil {
			return resp.DBConfigJSON, resp.MasterKey, nil
		}
	}
	return "", "", fmt.Errorf("no response or invalid JSON from scheduler")
}
```

```go
if dbCfg, masterKey, err := fetchCredentialsFromScheduler(); err == nil {
	if dbCfg != "" {
		os.Setenv("MITM_DB_CONFIG_JSON", dbCfg)
	}
	if masterKey != "" {
		os.Setenv("MASTER_KEY", masterKey)
	}
} else if os.Getenv("RUN_ID") != "" && os.Getenv("SCHEDULER_SOCKET_PATH") != "" {
	log.Printf("[IPC Warning] Failed to get credentials from scheduler: %v", err)
}
```

The scheduler answers `get_credentials` on the same connection with one JSON line `{"master_key": "...", "db_config_json": "..."}`. `master_key` is the scheduler's `MASTER_KEY` string as configured (base64 or raw); validate it with `validateKEK`.

### Status and Audit Events

Because collectors can be run standalone, the IPC logging client must check for `nil` to prevent panics outside of the scheduler environment. Every event is a single newline-delimited JSON message on a new socket connection. Once `topic` and `source_name` are known, messages are prefixed with `<topic>: <source_name>: `.

The scheduler dispatches on the `type` field:

- `"status"` → `job_status_events (run_id, status, message, progress)`; `component` is ignored.
- `"audit"` → `job_audit_logs (run_id, component, message)`.

Events are fire-and-forget: the scheduler sends no reply. Unknown or malformed messages are logged by the scheduler to `system_logs` and otherwise ignored.

```go
type StatusEvent struct {
	RunID     int    `json:"run_id"`
	Type      string `json:"type"` // "status" (default) or "audit"
	Component string `json:"component"`
	Status    string `json:"status"`
	Message   string `json:"message"`
	Progress  int    `json:"progress"`
}

type IPCClient struct {
	SocketPath string
	RunID      int
	Component  string
	Topic      string
	SourceName string
}

func (c *IPCClient) SendEvent(status, message string, progress int) {
	if c == nil || c.SocketPath == "" {
		return
	}
	conn, err := net.Dial("unix", c.SocketPath)
	if err != nil {
		log.Printf("[IPC ERROR] Failed to connect to scheduler socket: %v", err)
		return
	}
	defer conn.Close()

	if c.Topic != "" && c.SourceName != "" {
		message = fmt.Sprintf("%s: %s: %s", c.Topic, c.SourceName, message)
	}

	event := StatusEvent{
		RunID:    c.RunID,
		Type:     "status",
		Status:   status,
		Message:  message,
		Progress: progress,
	}
	data, _ := json.Marshal(event)
	_, _ = conn.Write(append(data, '\n'))
}

func (c *IPCClient) SendAudit(message string) {
	if c == nil || c.SocketPath == "" {
		return
	}
	conn, err := net.Dial("unix", c.SocketPath)
	if err != nil {
		log.Printf("[IPC ERROR] Failed to connect to scheduler socket: %v", err)
		return
	}
	defer conn.Close()

	if c.Topic != "" && c.SourceName != "" {
		message = fmt.Sprintf("%s: %s: %s", c.Topic, c.SourceName, message)
	}

	event := StatusEvent{
		RunID:     c.RunID,
		Type:      "audit",
		Component: c.Component,
		Message:   message,
	}
	data, _ := json.Marshal(event)
	_, _ = conn.Write(append(data, '\n'))
}
```

Instantiate the client only when running under the scheduler; otherwise it stays `nil`:

```go
var ipc *IPCClient
if runIDStr != "" && socketPath != "" {
	if runID, err := strconv.Atoi(runIDStr); err == nil {
		ipc = &IPCClient{SocketPath: socketPath, RunID: runID, Component: "mitm_collector_ora"}
	}
}
```

Set `ipc.Topic` and `ipc.SourceName` after the job overrides have been parsed. Progress milestones used by the reference implementation: `started` (0), connected to MitM DB (20), connected to source (50), preparing ingestion (70).

---

## 5. Ingestion Workflow & Key Unwrap

Your main entry point must execute the following sequence:

### Step 1: Connect to Target MitM Database

Fetch credentials via IPC (Section 4), parse the MitM configuration (`MITM_DB_CONFIG_JSON` or `MITM_DB_*`), parse and validate the overrides in `os.Args[1]`, build the DSN, and create a PostgreSQL connection pool bound to a signal-aware context for graceful shutdown:

```go
ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer cancel()

poolCfg, err := pgxpool.ParseConfig(mitmDSN)
if err == nil {
	poolCfg.MaxConns = 20
	poolCfg.MaxConnIdleTime = 5 * time.Minute
	poolCfg.MaxConnLifetime = 1 * time.Hour
}
var mitmPool *pgxpool.Pool
if err == nil {
	mitmPool, err = pgxpool.NewWithConfig(ctx, poolCfg)
}
```

### Step 2: Unwrap storage DEK using KEK

Load and validate the KEK (`validateKEK(os.Getenv("MASTER_KEY"))`). Query the encrypted source credentials and the wrapped DEK:

```go
// 1. Fetch encrypted config and DEK reference
err = mitmPool.QueryRow(ctx, `
	SELECT config_payload, nonce, dek_id
	FROM source_credentials
	WHERE source_name = $1 AND is_active = true
	LIMIT 1
`, targetCfg.SourceName).Scan(&configPayload, &credentialsNonce, &dekID)

// 2. Fetch wrapped key
err = mitmPool.QueryRow(ctx, `
	SELECT wrapped_key
	FROM storage_keys
	WHERE id = $1 AND is_active = true
	LIMIT 1
`, dekID).Scan(&wrappedKey)
```

The wrapped key is stored as `nonce (12 bytes) || ciphertext`. Unwrap it with the KEK, then decrypt the source credentials with the DEK:

```go
if len(wrappedKey) < 12 {
	log.Fatal("Wrapped DEK in database is invalid")
}
kekBlock, _ := aes.NewCipher(kek)
kekGCM, _ := cipher.NewGCM(kekBlock)
dek, err := kekGCM.Open(nil, wrappedKey[:12], wrappedKey[12:], nil)

dekBlock, _ := aes.NewCipher(dek)
dekGCM, _ := cipher.NewGCM(dekBlock)
decryptedConfigBytes, err := dekGCM.Open(nil, credentialsNonce, configPayload, nil)
```

(Error handling omitted for brevity; every error must be reported and terminate the process, see Section 6.)

Keep `dekGCM` — it is reused to encrypt every payload. Unmarshal `decryptedConfigBytes` into `SourceDBConfig` and connect to the source. Verify the connection (e.g. `Ping()`) before querying.

### Step 3: Incremental Query Loop

Retrieve the last cursor offset (a missing row means first run):

```go
err = mitmPool.QueryRow(ctx, "SELECT last_cursor FROM ingestion_cursors WHERE source_name = $1", targetCfg.SourceName).Scan(&lastCursor)
if err != nil && err != pgx.ErrNoRows {
	log.Printf("Warning: Failed to load cursor: %v", err)
}
```

Build the source query from validated identifiers and bound parameters (Oracle uses positional `:1`, `:2`, … placeholders):

```text
SELECT * FROM <table>
 [WHERE <col> IN (:1, :2, …) AND … AND <cursor_column> > :n]
 [ORDER BY <cursor_column> ASC]
```

- `db_where_in` adds one `IN (...)` condition per column.
- The cursor condition is only added when both `cursor_column` and `last_cursor` are set.
- `ORDER BY` is only added when a cursor column is configured; ascending order guarantees that the last processed row holds the highest cursor value.

Scan rows dynamically via `rows.Columns()` so the collector does not depend on the schema at compile time, and locate the cursor column case-insensitively (`strings.EqualFold`).

### Step 4: Encrypt and Ingest

For each database row fetched:

1. Map column names to values and normalize them (`[]byte` → `string`, `time.Time` → RFC 3339).
2. Serialize the row map to JSON.
3. Generate a random 12-byte nonce:
   ```go
   nonce := make([]byte, 12)
   _, err := io.ReadFull(rand.Reader, nonce)
   ```
4. Encrypt the JSON via AES-GCM using the DEK: `dekGCM.Seal(nil, nonce, rowJSON, nil)`.
5. Determine the business key (`business_key_column` value, else the row's cursor value; skip the row if neither exists) and derive the deterministic correlation ID:
   ```go
   namespaceMitM := uuid.MustParse("6ba7b810-9dad-11d1-80b4-00c04fd430c8")
   correlationID := uuid.NewSHA1(namespaceMitM, []byte(businessKey))
   ```
6. Queue the insert into a `pgx.Batch`:
   ```go
   batch.Queue(`
   	INSERT INTO raw_ingestion (topic, source_system, correlation_id, payload, nonce, dek_id, status)
   	VALUES ($1, $2, $3, $4, $5, $6, 'pending')
   `, topicName, targetCfg.SourceName, correlationID, encryptedPayload, nonce, dekID)
   ```
7. Keep track of the highest cursor value processed (`maxCursorValue`).
8. Flush the batch when it reaches 1000 entries (Step 5).

Rows that fail to scan, serialize, or encrypt are logged, counted as failed, and skipped.

### Step 5: Commit Batch and Cursor Atomically

Each batch is executed in its own transaction, together with the cursor upsert. Queue the cursor upsert as the last batch statement, then commit or roll back as a whole. Flush once more after the row loop for the remaining records.

```go
if cursorToSave != "" {
	batch.Queue(`
		INSERT INTO ingestion_cursors (source_name, last_cursor, updated_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (source_name)
		DO UPDATE SET last_cursor = EXCLUDED.last_cursor, updated_at = NOW()
	`, targetCfg.SourceName, cursorToSave)
}

tx, err := mitmPool.Begin(ctx)
// ... handle err: count batch as failed, reset batch, return
br := tx.SendBatch(ctx, batch)
var batchError error
for i := 0; i < batchSize; i++ {
	if _, err := br.Exec(); err != nil {
		batchError = err
		break
	}
}
if cursorToSave != "" && batchError == nil {
	if _, err := br.Exec(); err != nil {
		batchError = err
	}
}
br.Close()

if batchError != nil {
	tx.Rollback(ctx)
	recordsFailed += batchSize
} else if err := tx.Commit(ctx); err != nil {
	recordsFailed += batchSize
} else {
	recordsIngested += batchSize
}
batch = &pgx.Batch{}
batchSize = 0
```

Never update the cursor in a separate statement or transaction from the records it covers.

---

## 6. Exit Codes & Error Handling

The scheduler evaluates **only the exit code** of the collector: it stores `finished_at`, `exit_code` and `success` in `program_runs`. Status events do not influence the result of a run.

- **Exiting on Failure:** If an unrecoverable error occurs (e.g. invalid configuration or identifier, database connection failure, decryption failure, failed source query), send a `"failed"` status event via IPC (if configured) and exit using `log.Fatal` / `os.Exit(1)`. Do not include secrets (passwords, keys, decrypted payloads) in events or logs.
- **Exiting on Success:** When ingestion finishes, send audit events summarizing the result (records ingested/failed, new cursor value) and the final `<appName> (<version>) finished` audit, then exit with status code `0` (default on `main()` completion). The reference implementation signals completion this way and does not emit a separate `finished` status event.
- **Restarts:** If the job has `restart_on_exit = true`, the scheduler restarts it immediately after a non-zero exit (not after being killed by a signal) with a new `RUN_ID`. Collectors must therefore be safe to re-run: the cursor in `ingestion_cursors` is what prevents re-ingesting committed data.
- **Termination:** On a stop request or scheduler shutdown the collector receives `SIGTERM`, followed by `SIGKILL` after 5 seconds. Bind all database work to a `signal.NotifyContext` context so that open transactions are rolled back instead of half-committed.
- **Console Output:** The scheduler pipes the collector's stdout/stderr but does not read them. Keep console logging minimal (no per-row logging); report details via IPC audit events instead.

---

## 7. Build & Versioning

Build a static binary and inject the version from the Git tag:

```sh
MITM_VERSION=$(git describe --tags)
CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=${MITM_VERSION}" -o ./bin/mitm-collector-ora main.go
cp bin/mitm-collector-ora ../../app/bin/.
```

Declare `version` as a package-level `var` (not `const`) so `-X` can override it. At startup, strip the `git describe` suffix (`strings.Split(version, "-")[0]`) before reporting it.

Provide unit tests for pure helpers such as `validateKEK` (`main_test.go`) and run them with `go test ./...`.
