# Developer Guide: Creating a Data Ingestion Collector

This guide describes how to implement a new data collector in the **Man-in-the-Middle (MitM) Data Aggregator** system. Collectors are autonomous, standalone Go binaries that are executed by the scheduler to pull raw data from a source system, encrypt it, and write it to the central database landing zone.

---

## 1. Core Principles & Requirements

Every collector must adhere to the following design standards:

- **Standalone Go Binary:** Build the collector as an independent Go program with its own `go.mod`. Do not couple it directly to the scheduler module tree.
- **Envelope Encryption First:** All data written to the `raw_ingestion` landing zone must be encrypted with AES-GCM (12-byte random nonce) using a Data Encryption Key (DEK) retrieved from the target database.
- **State Preservation (Cursors):** Query the source database incrementally using state-based cursors (e.g. tracking auto-incrementing IDs or modification timestamps) stored in `ingestion_cursors`.
- **Nil-Safe IPC Logging:** Communicate execution progress and audit events back to the parent scheduler over a Unix Domain Socket if environmental variables are present. The IPC client must be nil-safe to allow standalone CLI execution for debugging.
- **Standardized SPDX Headers:** Every source file must include the standardized Apache-2.0 SPDX header at the top.

---

## 2. Bootstrapping & CLI Arguments

A collector accepts two command-line arguments:

1. **`os.Args[1]` (Required):** A JSON string detailing the connection parameters to the central MitM target database.
2. **`os.Args[2]` (Optional):** A JSON string injected by the scheduler containing job-specific configuration overrides (e.g., target table name, source name, cursor column).

### TargetDBConfig Struct

Define the structure for parsing `os.Args[1]`:

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

### Job Overrides Struct

Define the structure for parsing the optional `os.Args[2]`:

```go
type CollectorArgs struct {
	SourceName   string `json:"source_name"`
	Table        string `json:"table"`
	CursorColumn string `json:"cursor_column"` // E.g., for dynamic schemas
	Topic        string `json:"topic"`         // Target routing topic
}
```

---

## 3. Environment Variables

Collectors load context and security keys from the following environment variables:

- **`MASTER_KEY` (Required):** The base64-encoded 32-byte Master Key (KEK) used to unwrap the storage DEK.
- **`RUN_ID` (Optional):** The run instance ID injected by the scheduler.
- **`SCHEDULER_SOCKET_PATH` (Optional):** The file path to the Unix Domain Socket of the scheduler.

---

## 4. Nil-Safe IPC Client Implementation

Because collectors can be run standalone, the IPC logging client must check for `nil` to prevent panics when running outside of the scheduler environment.

Copy this standard IPC implementation pattern:

```go
type StatusEvent struct {
	RunID    int    `json:"run_id"`
	Type     string `json:"type"` // "status" or "audit"
	Status   string `json:"status"`
	Message  string `json:"message"`
	Progress int    `json:"progress"`
}

type IPCClient struct {
	SocketPath string
	RunID      int
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

	event := StatusEvent{
		RunID:    c.RunID,
		Type:     "status",
		Status:   status,
		Message:  message,
		Progress: progress,
	}
	data, _ := json.Marshal(event)
	_, _ = conn.Write(append(data, '\n')) // Delimited by a newline character
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

	event := StatusEvent{
		RunID:   c.RunID,
		Type:    "audit",
		Message: message,
	}
	data, _ := json.Marshal(event)
	_, _ = conn.Write(append(data, '\n'))
}
```

### Status and Audit Events

Send progress and status milestones to the scheduler via `SendEvent` and audit events via `SendAudit`. See `../mitm_collector_pg-employee/main.go` for an example implementation.

---

## 5. Ingestion Workflow & Key Unwrap

Your main entry point must execute the following sequence:

### Step 1: Connect to Target MitM Database

Parse `os.Args[1]`, parse overrides in `os.Args[2]`, construct the connection string, and instantiate a PostgreSQL connection pool.

```go
mitmPool, err := pgxpool.New(ctx, mitmDSN)
```

### Step 2: Unwrap storage DEK using KEK

Read the KEK from the `MASTER_KEY` environment variable. Query the database to retrieve the wrapped DEK and the encrypted source credentials:

```go
// 1. Fetch encrypted config and KEK/DEK parameters
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

Decrypt the wrapped key using the KEK (AES-GCM), and then decrypt the source database credentials using the resulting DEK.

### Step 3: Incremental Query Loop

Retrieve the last cursor offset:

```go
err = mitmPool.QueryRow(ctx, "SELECT last_cursor FROM ingestion_cursors WHERE source_name = $1", targetCfg.SourceName).Scan(&lastCursor)
```

Query the source database for all records with an ID greater than the cursor offset.

### Step 4: Encrypt and Ingest

For each database row fetched:

1. Serialize the row data to JSON.
2. Generate a random 12-byte nonce:
   ```go
   nonce := make([]byte, 12)
   _, err := io.ReadFull(rand.Reader, nonce)
   ```
3. Encrypt the serialized JSON via AES-GCM using the DEK.
4. Insert the payload, nonce, topic, and referenced `dek_id` into the `raw_ingestion` table.
5. Keep track of the highest cursor value processed (`maxCursorValue`).

### Step 5: Update Ingestion Cursor

If any records were successfully inserted, update the offset:

```go
_, err = mitmPool.Exec(ctx, `
	INSERT INTO ingestion_cursors (source_name, last_cursor, updated_at)
	VALUES ($1, $2, NOW())
	ON CONFLICT (source_name)
	DO UPDATE SET last_cursor = EXCLUDED.last_cursor, updated_at = NOW()
`, targetCfg.SourceName, maxCursorValue)
```

---

## 6. Exit Codes & Error Handling

To ensure the scheduler can track job failures and initiate retries if necessary:

- **Exiting on Failure:** If an unrecoverable error occurs (e.g. database connection failure, decryption failure), send a `"failed"` status event via IPC (if configured) and exit using `log.Fatal` or `os.Exit(1)`.
- **Exiting on Success:** When ingestion finishes successfully, send a `"finished"` event with progress `100` and exit with status code `0` (default on `main()` completion).
