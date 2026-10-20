# Collector Layer Concept: Encrypted RAW Ingestion

## Overview
The Collector Layer consists of independent Go programs responsible for fetching data from various source systems (APIs, SQL, CSV) and storing it in a central PostgreSQL **RAW Table**. 

To ensure security and compliance (GDPR/PII), all sensitive data is protected using **Envelope Encryption** (AES-GCM) before it hits the database.

The reference implementation for this concept is the Oracle collector in [`./mitm_collector_ora`](./mitm_collector_ora/main.go).

## Security Architecture: Envelope Encryption
Following the project's security standards, we use a two-tier key hierarchy:
1.  **Master Key (KEK):** A 32-byte key that resides only in the RAM of the Go processes. It is requested at startup via the Scheduler IPC socket (`get_credentials`) and is never persisted. The scheduler does not pass it through the process environment. For standalone debugging it may be supplied via the `MASTER_KEY` environment variable (base64-encoded or 32 raw bytes).
2.  **Data Encryption Keys (DEKs):** Keys used for data encryption. They are stored in the database but are "wrapped" (encrypted) by the KEK. A wrapped key is stored as `nonce (12 bytes) || AES-GCM ciphertext`.

The DEK referenced by a source's `source_credentials` entry is used both to decrypt that source's connection config and to encrypt every payload the collector writes for that source. Each written record references this DEK via `dek_id`.

## Database Schema

### 1. Key Management (`storage_keys`)
Stores the encrypted DEKs.

```sql
CREATE TABLE storage_keys (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wrapped_key  BYTEA NOT NULL,                 -- DEK encrypted with KEK (nonce || ciphertext)
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    expires_at   TIMESTAMPTZ,                    -- For key rotation support
    is_active    BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE storage_keys IS 'Stores wrapped Data Encryption Keys (DEKs) for Envelope Encryption.';
```

### 2. Source Credentials (`source_credentials`)
Stores connection details for source systems. The entire configuration (JSON) is encrypted.

```sql
CREATE TABLE source_credentials (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name     VARCHAR(100) NOT NULL UNIQUE, -- e.g., 'SAP_HR_PROD'
    connector_type  VARCHAR(50) NOT NULL,        -- e.g., 'REST_API', 'POSTGRESQL'
    topic           VARCHAR(100) NOT NULL,       -- e.g., 'Employee'
    
    -- Encrypted Connection Config
    -- Contains sensitive fields: host, port, username, password, api_key
    config_payload  BYTEA NOT NULL,              -- AES-GCM encrypted JSON
    nonce           BYTEA NOT NULL,              -- 12-byte IV for AES-GCM
    dek_id          UUID NOT NULL,               -- Reference to storage_keys
    
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_dek_creds FOREIGN KEY (dek_id) REFERENCES storage_keys(id)
);
```

For a SQL source such as Oracle, the decrypted `config_payload` is a JSON object like:

```json
{
  "host": "ora.example.local",
  "port": 1521,
  "user": "reader",
  "password": "secret",
  "service": "ORCLPDB1",
  "sid": "",
  "database": "",
  "dsn": ""
}
```

A non-empty `dsn` takes precedence; otherwise the connection URL is built from `host`, `port`, `service` (or `sid`, or `database` as fallback), `user` and `password`.

### 3. RAW Ingestion Table (`raw_ingestion`)
The landing zone for all collected data fragments.

```sql
CREATE TABLE raw_ingestion (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Unencrypted Metadata for Routing/Orchestration
    topic           VARCHAR(255) NOT NULL,       -- e.g., 'employee.onboarding'
    source_system   VARCHAR(100) NOT NULL,       -- e.g., 'SAP_HR'
    correlation_id  UUID,                        -- For end-to-end tracing
    
    -- Encrypted Data Payload
    payload         BYTEA NOT NULL,              -- AES-GCM encrypted fragment
    nonce           BYTEA NOT NULL,              -- 12-byte IV
    dek_id          UUID NOT NULL,               -- Reference to storage_keys
    
    -- Status Management
    status          VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    retry_count     INT DEFAULT 0,
    
    -- Audit Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    processed_at    TIMESTAMPTZ,
    
    CONSTRAINT fk_dek_raw FOREIGN KEY (dek_id) REFERENCES storage_keys(id)
);

-- Index for efficient Orchestrator polling
CREATE INDEX idx_raw_pending_topics ON raw_ingestion (topic, status) WHERE status = 'pending';
```

Collectors write `source_system = source_name` and always insert with `status = 'pending'`.

### 4. Ingestion Cursors (`ingestion_cursors`)
Tracks the last processed offset per source, enabling incremental extraction.

```sql
CREATE TABLE ingestion_cursors (
    source_name  VARCHAR(100) PRIMARY KEY,
    last_cursor  VARCHAR(255) NOT NULL,
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ingestion_cursors IS 'Tracks last processed data offset per source system.';
```

## Correlation ID
Every RAW record carries a deterministic `correlation_id` so that the Transformation Layer can join fragments of the same business entity across sources (Stateful Aggregation):

*   The business key is the value of the configured `business_key_column`; if it is missing, the row's cursor value is used. Rows without either are skipped and counted as failed.
*   `correlation_id = UUIDv5(namespace 6ba7b810-9dad-11d1-80b4-00c04fd430c8, business_key)`.

The same business key therefore always yields the same `correlation_id`, regardless of the collector or run.

## Scheduler Integration
Collectors are started and supervised by the Scheduler Server [`/core-layer/mitm_scheduler-server`](../core-layer/mitm_scheduler-server/src/job_runner.rs) (Rust).

*   **Job definition:** Each collector job is a row in `scheduled_programs` (`name`, `command`, `args` JSONB, `cron_expr`, `enabled`, `restart_on_exit`). Jobs are triggered by cron or manually via the HTTP server (`execute_job` / `run_immediate_job`). A job that is still running is not started a second time.
*   **Process start:** For every run the scheduler creates a `program_runs` row; its `id` is the `RUN_ID`. `command` is resolved relative to the scheduler executable's directory, which is also the working directory. The job's `args` JSON is passed as the single CLI argument (`{}` if empty).
*   **Environment:** The child environment is cleared. Only `PATH`, `SYSTEMROOT`, `USERPROFILE`, `HOME`, `TEMP`, `TMP` and all `MITM_*` variables are inherited, plus `RUN_ID` and `SCHEDULER_SOCKET_PATH` (`<socket_dir>/mitm_scheduler.sock`). `MASTER_KEY` is **not** inherited; collectors receive it only via IPC.
*   **IPC socket:** Newline-delimited JSON over the Unix Domain Socket, tagged by `type`:

    | `type`            | Sent by collector                                  | Scheduler action                                                                      |
    | ----------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------- |
    | `get_credentials` | `run_id`                                           | Replies `{"master_key": "...", "db_config_json": "..."}` on the same connection      |
    | `status`          | `run_id`, `status`, `message`, `progress`          | Inserts into `job_status_events`                                                      |
    | `audit`           | `run_id`, `component`, `message`                   | Inserts into `job_audit_logs`                                                         |

    `db_config_json` is the scheduler's own serialized configuration; collectors only use its `db` object (`host`, `port`, `user`, `password`, `database`, `sslmode`).
*   **Run result:** Success is determined solely by the process exit code: the scheduler stores `finished_at`, `exit_code` and `success` in `program_runs`. Status events are informational only. With `restart_on_exit = true`, a run that exits non-zero (and was not killed by a signal) is restarted immediately with a new `RUN_ID`.
*   **Stop / shutdown:** A stop request or scheduler shutdown sends `SIGTERM`; a job still alive after 5 seconds receives `SIGKILL`.
*   **Logging:** The scheduler itself writes lifecycle and errors to `system_logs`. Collectors never write log tables directly.

## Workflow

### Collector Process
1.  **Initialize:** If `RUN_ID` and `SCHEDULER_SOCKET_PATH` are set, request `get_credentials` from the Scheduler IPC socket and receive the MitM database config (`db_config_json`) and the Master Key (`master_key`). Without a scheduler (standalone debugging), both are read from the environment.
2.  **Fetch Credentials:** 
    *   Query `source_credentials` for the specific `source_name` (`is_active = true`).
    *   Retrieve the referenced `wrapped_key` from `storage_keys` (`is_active = true`).
    *   Unwrap DEK using KEK (first 12 bytes are the nonce).
    *   Decrypt `config_payload` using DEK and `nonce`.
3.  **Ingest Data:** Use decrypted credentials to connect to the source and fetch data incrementally:
    *   Load `last_cursor` for the `source_name` from `ingestion_cursors`.
    *   Query only rows with `cursor_column > last_cursor`, ordered ascending by the cursor column. Optional `db_where_in` filters add `column IN (...)` conditions with bound parameters.
    *   Table and column identifiers used in dynamic SQL are validated against `^[a-zA-Z0-9_]+$`; values are always bound parameters.
4.  **Encrypt & Store:**
    *   Serialize each row to JSON (`[]byte` → string, timestamps → RFC 3339).
    *   Generate a fresh random 12-byte `nonce`.
    *   Encrypt the JSON with AES-GCM using the source's DEK.
    *   Derive the deterministic `correlation_id`.
    *   Insert the record into `raw_ingestion` with `status = 'pending'`.
5.  **Commit atomically:** Rows are written in batches of up to 1000. Each batch and the `ingestion_cursors` upsert (highest cursor value of that batch) run in **one transaction**: either both are committed or both are rolled back. A failed batch is rolled back and counted as failed; its cursor update is discarded together with its records.
6.  **Report:** Status (`started`, `processing`, `failed`) and audit events are sent to the Scheduler via the Unix Domain Socket throughout the run. Unrecoverable errors terminate the process with a non-zero exit code, which the scheduler records as a failed run.

### Orchestrator Process
1.  **Poll:** Select `pending` records from `raw_ingestion`.
2.  **Decrypt:** Retrieve DEK (unwrap with KEK) and decrypt the `payload`.
3.  **Process:** Transform, aggregate, and prepare for target delivery.
4.  **Update:** Set `status` to `completed` and set `processed_at`.

## Benefits
*   **Security:** Data is never stored in plaintext. Even DB administrators cannot read it without the KEK.
*   **Decoupling:** Collectors don't need to know the final destination; they just "dump and run" into the RAW table.
*   **Consistency:** Atomic batch + cursor commits ensure that records and the cursor progress of a batch are always committed together.
*   **Traceability:** `correlation_id` and `source_system` allow for clear audit trails.
*   **Compliance:** "Crypto-shredding" is possible by deleting the specific DEK for a source or time range.
