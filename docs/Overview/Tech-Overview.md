# MitM Data Aggregator — Technical Overview

> **Deep-dive reference covering code structure, database schemas, configuration contracts, IPC protocols, encryption internals, and CLI interfaces for every layer.**
> Intended for developers, operations engineers, and integrators.

---

## Table of Contents

1. [System Architecture & Data Flow](#1-system-architecture--data-flow)
2. [Root Project (Repository Root)](#2-root-project-repository-root)
3. [MitM Scheduler](#3-mitm-scheduler)
4. [Collector Layer](#4-collector-layer)
5. [Transformation Layer](#5-transformation-layer)
6. [Delivery Layer](#6-delivery-layer)
7. [Maintenance Layer](#7-maintenance-layer)
8. [Admin Frontend](#8-admin-frontend)
9. [Security Internals](#9-security-internals)
10. [Appendix: Database Schemas & Migrations](#10-appendix-database-schemas--migrations)

---

## 1. System Architecture & Data Flow

### High-Level Pipeline

```
Source Systems                    MitM Aggregator                         Target SaaS
   (PG DB) -----+
                 |
   (Oracle DB) --+--> [Collector Layer] --> [Transformation Layer] --> [Delivery Layer] --HTTPS--> SaaS API
                 |         |                       |                        |
   (CSV/Excel) --+    raw_ingestion           target_fragments          packages
                 |         |                   (encrypted)              (JSON)
   (Kafka) ------+    (encrypted)                                         |
                                                                     dead_letter_queue
                                                                       (DLQ)
```

### Runtime Sequence (Three-Phase Daily Workflow)

**Phase 1 — Ingest & Transform**

```
MitM-Scheduler -> Collector -> Transformation -> DB (target_fragments)
```

**Phase 2 — Packaging (every 24h)**

```
MitM-Scheduler -> Delivery Packager -> DB (packages)
```

**Phase 3 — Delivery**

```
MitM-Scheduler -> Delivery Sender -> SaaS (HTTPS POST)
```

### Go Module Dependency Tree

The project uses standalone Go modules — each layer has its own `go.mod`. All inter-layer communication goes through PostgreSQL (data) and Unix Domain Sockets (IPC).

```
mitm-2/                              (root — no go.mod, documentation only)
+-- scheduler/mitm_scheduler/        go.mod -> mitm_scheduler
+-- collector-layer/
|   +-- mitm_collector_pg/           go.mod -> mitm_collector_pg
|   +-- mitm_collector_ora/          go.mod -> mitm_collector_ora
|   +-- mitm_collector_csv-xls/      go.mod -> mitm_collector_csv_xls
|   +-- mitm_collector_kafka/        go.mod -> mitm_collector_kafka
+-- transformation-layer/
|   +-- mitm_transformation/         go.mod -> mitm_transformation
+-- delivery-layer/
|   +-- mitm_delivery/               go.mod -> mitm_delivery
+-- maintenance-layer/
|   +-- mitm_cleanup/                go.mod -> mitm_cleanup
+-- admin-frontend/
    +-- mitm_fe_cpp/                 (C++/CMake — no go.mod)
```

---

## 2. Root Project (Repository Root)

### Project Structure

```
./
+-- bin/                    Compiled binaries (symlinks or copies)
+-- data/                   Test data (CSV exports, SQL seeds, Kafka scripts)
+-- docs/                   ERD diagram, example config guide
+-- img/                    Logos, architecture diagrams
+-- migrations/             Shared setup.sql (schema bootstrap)
+-- overview/               This document
+-- overview_mgmt/          Management overview
+-- collector-layer/        Source collectors
+-- delivery-layer/         Package and delivery
+-- maintenance-layer/      Cleanup jobs
+-- scheduler/              Scheduler daemon
+-- transformation-layer/   Transformation engine
+-- admin-frontend/         Desktop application
```

### End-to-End Test Script (`test_e2e.sh`)

Validates the entire pipeline locally:

1. Spins up a mock SaaS HTTP server (`mock_saas.go`).
2. Seeds test data into PostgreSQL (CSV to SQL imports).
3. Runs the collector to ingest encrypted fragments.
4. Runs the transformer to build Golden Records.
5. Runs the deliverer to package and POST to the mock SaaS.
6. Asserts all fragments are delivered and DLQ is empty.

### Mock SaaS Server (`mock_saas.go`)

A lightweight Go HTTP server that mimics the target SaaS REST API:

- Endpoint: `POST /api/v1/ingest`
- Accepts JSON payload with `Idempotency-Key` header.
- Returns `202 Accepted` on success, `429`/`503` on simulated failures.
- Logs all received payloads to stdout.

### Data Files (`data/`)

| File                         | Purpose                                               |
| :--------------------------- | :---------------------------------------------------- |
| `2026-06-29_employee.csv`    | Sample CSV for CSV collector testing                  |
| `2026-06-29_employee_pg.sql` | PostgreSQL seed data for PG collector                 |
| `mirror-dev_employee.csv`    | Mirror CSV import                                     |
| `_convert_csv_to_sql.py`     | Utility to convert CSV to SQL INSERT statements       |
| `_lowercase_columns.py`      | Utility to normalize column casing                    |
| `reset_data.sql`             | Drops and re-creates test data                        |
| `kafka/hr_kafka.py`          | Python Kafka producer for testing the Kafka collector |
| `kafka/main.go`              | Go Kafka test producer                                |
| `example_config.sql`         | Reference SQL for full pipeline configuration         |

---

## 3. MitM Scheduler

**Location:** `scheduler/mitm_scheduler/`
**Binary:** `mitm-server` (from `cmd/scheduler`)
**Repository:** [github.com/Zheng-Bote/mitm_scheduler](https://github.com/Zheng-Bote/mitm_scheduler)

### Project Structure

```
scheduler/mitm_scheduler/
+-- cmd/
|   +-- scheduler/              Main daemon entrypoint
|   +-- encrypt-config/         Utility to encrypt config.json
|   +-- scheduler-admin/        Fyne-based GUI admin (cross-platform)
|   +-- job1/                   Example job demonstrating IPC
|   +-- job2/                   Example job demonstrating audit
+-- internal/
|   +-- crypto/                 AES-256-GCM + Argon2id config encryption
|   +-- db/                     PostgreSQL connection pool, migrations
|   +-- ipc/                    Unix Domain Socket server/client
|   +-- http/                   REST API handlers, middleware, auth
|   +-- scheduler/              Cron engine, job runner
+-- migrations/                 SQL DDL files
+-- docs/                       Architecture, API, DB schema docs
+-- Dockerfile
+-- example_config.json
```

### CLI Usage

```bash
# Build
go build -o ./bin/mitm-server ./cmd/scheduler
go build -o ./bin/encrypt-config ./cmd/encrypt-config

# Encrypt config
./encrypt-config config.json config.json.enc

# Run daemon
./mitm-server config.json.enc
# Password via prompt or SCHEDULER_PASSWORD env var

# Docker
docker build -t go-scheduler .
docker run -p 8080:8080 -e SCHEDULER_PASSWORD=mypassword \
  go-scheduler ./mitm-server /app/config.json.enc
```

### Configuration Format (`config.json`)

```json
{
  "db": {
    "host": "your-db-host",
    "port": 5432,
    "user": "your-user",
    "password": "your-password",
    "database": "your-dbname",
    "db_connect_delay": 30,
    "sslmode": false
  },
  "http_port": 8080,
  "use_https": false,
  "ssl_cert": "server.crt",
  "ssl_key": "server.key",
  "log_level": "DEBUG",
  "upload_dir": "/tmp/mitm_uploads",
  "admins": [{ "username": "admin1", "token": "your_secure_token" }]
}
```

Encrypted with AES-256-GCM + Argon2id key derivation. Decryption password from prompt or `SCHEDULER_PASSWORD`.

### REST API Endpoints

| Endpoint                    | Method | Auth                   | Purpose                                |
| :-------------------------- | :----- | :--------------------- | :------------------------------------- |
| `/health`                   | GET    | None                   | Liveness check                         |
| `/info`                     | GET    | None                   | Build version, uptime                  |
| `/time`                     | GET    | None                   | Server local time                      |
| `/admin/update-jobs`        | POST   | Basic                  | Upsert one or more jobs                |
| `/admin/logs/system`        | GET    | Basic                  | Download system logs with date filter  |
| `/admin/logs/job-status`    | GET    | Basic                  | Download job status events             |
| `/admin/logs/job-audit`     | GET    | Basic                  | Download job audit logs                |
| `/admin/logs/admin-audit`   | GET    | Basic                  | Download admin audit logs              |
| `/admin/upload/source_file` | POST   | Basic (UPLOADER/ADMIN) | Upload CSV/Excel for dynamic collector |

#### Create/Update Job Example

```bash
curl -u "admin1:your_secure_token" -X POST \
  -H "Content-Type: application/json" \
  -d '[{
    "name": "PG_EMPLOYEE_COLLECTOR",
    "command": "./bin/mitm-collector-pg",
    "args": {
      "source_name": "PG_EMPLOYEE",
      "table": "employees",
      "cursor_column": "id",
      "topic": "employee.data",
      "business_key_column": "employee_id"
    },
    "cron_expr": "*/5 * * * *",
    "enabled": true,
    "restart_on_exit": false
  }]' \
  http://localhost:8080/admin/update-jobs
```

### IPC Protocol (Unix Domain Socket)

Jobs communicate back to the scheduler via JSON-Lines over a Unix Domain Socket.

**Socket path:** `SCHEDULER_SOCKET_PATH` environment variable.

```go
type StatusEvent struct {
    RunID    int    `json:"run_id"`
    Type     string `json:"type"`    // "status" or "audit"
    Status   string `json:"status"`
    Message  string `json:"message"`
    Progress int    `json:"progress"`
}
```

Messages are newline-delimited JSON. The IPC client is nil-safe — if `SCHEDULER_SOCKET_PATH` is empty, calls are silently ignored.

### Injected Environment Variables

| Variable                | Source                | Example                                       |
| :---------------------- | :-------------------- | :-------------------------------------------- |
| `RUN_ID`                | Auto-generated        | `1531`                                        |
| `SCHEDULER_SOCKET_PATH` | Config                | `/tmp/scheduler.sock`                         |
| `MITM_DB_CONFIG_JSON`   | Config                | `{"db":{"host":"127.0.0.1","port":5432,...}}` |
| `MITM_DB_HOST`          | Config (fallback)     | `127.0.0.1`                                   |
| `MITM_DB_PORT`          | Config (fallback)     | `5432`                                        |
| `MITM_DB_USER`          | Config (fallback)     | `postgres`                                    |
| `MITM_DB_PASSWORD`      | Config (fallback)     | `***`                                         |
| `MITM_DB_NAME`          | Config (fallback)     | `mitm`                                        |
| `MITM_DB_SSLMODE`       | Config (fallback)     | `true`                                        |
| `MASTER_KEY`            | Scheduler environment | `o3+A5...==`                                  |

### Database Migrations (Scheduler)

| File                           | Purpose                                                       |
| :----------------------------- | :------------------------------------------------------------ |
| `000_db.sql`                   | Database creation                                             |
| `001_init.sql`                 | Core job scheduling tables (`scheduled_programs`, `job_runs`) |
| `002_logging_and_audit.sql`    | `system_logs`, `job_status_events`, `job_audit_logs`          |
| `003_admin_and_api.sql`        | `admin_audit_logs`, HTTP config, admin roles                  |
| `004_add_name_unique.sql`      | Unique constraint on job name                                 |
| `005_change_args_to_jsonb.sql` | Migrate args column to JSONB                                  |
| `006_rbac.sql`                 | Role-based access control tables                              |

### Scheduler Admin GUI (`cmd/scheduler-admin`)

Built with **Fyne** (Go GUI framework). Cross-platform.

```bash
# Linux
go build -o ./bin/scheduler-admin ./cmd/scheduler-admin
# Windows (with Hello biometrics)
go build -v -ldflags="-H=windowsgui" -o ./bin/scheduler-admin.exe \
  ./cmd/scheduler-admin/main.go ./cmd/scheduler-admin/hello_windows.go
```

**UI layout:** Connection Settings (URL, Admin User, Auth Token), Action Toolbar (Load Jobs, New Job), Jobs Table, Job Editor Dialog (Name, Command, Args, Cron, Enabled, Restart on Exit, Delete).

**Windows Hello integration:** Platform check at runtime. Linux/macOS uses `hello_other.go` (no-op). Windows uses `hello_windows.go` with WinRT `UserConsentVerifier`. Biometric verification required before any REST API call.

---

## 4. Collector Layer

**Location:** `collector-layer/`

### Shared Database Schema (all collectors)

#### `storage_keys` — Wrapped DEK Storage

```sql
CREATE TABLE storage_keys (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wrapped_key  BYTEA NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    expires_at   TIMESTAMPTZ,
    is_active    BOOLEAN DEFAULT TRUE
);
```

#### `source_credentials` — Encrypted Source Configs

```sql
CREATE TABLE source_credentials (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name     VARCHAR(100) NOT NULL UNIQUE,
    connector_type  VARCHAR(50) NOT NULL,
    config_payload  BYTEA NOT NULL,
    nonce           BYTEA NOT NULL,
    dek_id          UUID NOT NULL REFERENCES storage_keys(id),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

#### `raw_ingestion` — Encrypted Data Landing Zone

```sql
CREATE TABLE raw_ingestion (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic           VARCHAR(255) NOT NULL,
    source_system   VARCHAR(100) NOT NULL,
    correlation_id  UUID,
    payload         BYTEA NOT NULL,
    nonce           BYTEA NOT NULL,
    dek_id          UUID NOT NULL REFERENCES storage_keys(id),
    status          VARCHAR(50) DEFAULT 'pending',
    retry_count     INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    processed_at    TIMESTAMPTZ
);
CREATE INDEX idx_raw_pending_topics ON raw_ingestion (topic, status) WHERE status = 'pending';
```

#### `ingestion_cursors`

```sql
CREATE TABLE ingestion_cursors (
    source_name VARCHAR(100) PRIMARY KEY,
    last_cursor VARCHAR(255) NOT NULL,
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### Common Collector Bootstrap Sequence (Go)

```go
// Step 1: Parse target DB connection
type TargetDBConfig struct {
    Host, Port, User, Password, Database, DSN, SourceName string
}
// From MITM_DB_CONFIG_JSON or individual MITM_DB_* env vars

// Step 2: Parse optional job overrides from os.Args[1]
type CollectorArgs struct {
    SourceName, Table, CursorColumn, Topic, BusinessKeyColumn string
}

// Step 3: Initialize nil-safe IPC client
type IPCClient struct {
    SocketPath string
    RunID      int
}
func (c *IPCClient) SendEvent(status, message string, progress int) {
    if c == nil || c.SocketPath == "" { return }
    // Unix Domain Socket dial + JSON-Lines write
}
func (c *IPCClient) SendAudit(message string) {
    // Same pattern, type="audit"
}

// Step 4: Unwrap DEK using KEK
kek, _ := base64.StdEncoding.DecodeString(os.Getenv("MASTER_KEY"))
// SELECT wrapped_key FROM storage_keys WHERE id = $1
// Decrypt wrapped_key with kek via AES-GCM

// Step 5: Decrypt source credentials
// SELECT config_payload, nonce FROM source_credentials WHERE source_name = $1
// Decrypt config_payload with DEK

// Step 6: Connect to source, query with cursor
// SELECT * FROM source_table WHERE id > $lastCursor ORDER BY id

// Step 7: For each row, encrypt and insert into raw_ingestion
nonce := make([]byte, 12)
io.ReadFull(rand.Reader, nonce)
ciphertext := aesGCM.Seal(nil, nonce, jsonRow, nil)
// INSERT INTO raw_ingestion (topic, source_system, correlation_id, payload, nonce, dek_id)

// Step 8: Update cursor
// UPSERT INTO ingestion_cursors (source_name, last_cursor)
```

### Collector Implementations

#### 4.1 PostgreSQL Collector (`mitm_collector_pg`)

**Source:** External PostgreSQL database.
**Driver:** `github.com/jackc/pgx/v5`
**Build:** `go build -o ../../bin/mitm-collector-pg main.go`

```json
// Job args
{
  "source_name": "mirror-dev_employee",
  "table": "employee",
  "cursor_column": "id",
  "topic": "Employee",
  "business_key_column": "employee_id"
}
```

**Extraction:** `SELECT * FROM <table> WHERE <cursor_column> > <lastCursor> ORDER BY <cursor_column>`
**Cursor type:** Integer (auto-incrementing ID).

#### 4.2 Oracle Collector (`mitm_collector_ora`)

**Source:** Oracle database.
**Driver:** `github.com/sijms/go-ora/v2` (pure Go, no Oracle client).
**Build:** `go build -o bin/mitm-collector-ora main.go`

Dynamic column scanning: queries `ALL_TAB_COLUMNS` at runtime, resolves into `map[string]string`.

```json
// Job args
{
  "source_name": "ORA_EMPLOYEE",
  "table": "EMPLOYEES",
  "cursor_column": "ID",
  "topic": "employee.data",
  "business_key_column": "EMPLOYEE_ID"
}
```

#### 4.3 CSV / Excel Collector (`mitm_collector_csv-xls`)

**Trigger:** Dynamic — launched by scheduler after `POST /admin/upload/source_file`.
**Build:** `go build -o ../../bin/mitm-collector-csv-xls main.go`

```json
// Job args (injected by scheduler)
{
  "file": "/tmp/mitm_uploads/employee_2026-07-21.csv",
  "source_name": "FILE_UPLOAD",
  "topic": "TARGET_TOPIC_NAME",
  "business_key_column": "Personalnummer"
}
```

**Security:** Temporary uploaded file removed with `os.Remove` after processing.

#### 4.4 Kafka Collector (`mitm_collector_kafka`)

**Source:** Apache Kafka / Confluent Cloud.
**Driver:** `github.com/segmentio/kafka-go` (SASL/PLAIN + TLS).
**Build:** `go build -o bin/mitm-collector-kafka ./main.go`

```json
// Job args
{
  "source_name": "KAFKA_EMPLOYEE",
  "topic": "cnx.hrmasterdata.Employee.v2",
  "business_key_column": "pernr",
  "idle_timeout_seconds": 60
}
```

Subscribes to topic, reads messages until idle timeout, encrypts each as a fragment. Falls back to Kafka native message key if `business_key_column` is absent.

---

## 5. Transformation Layer

**Location:** `transformation-layer/mitm_transformation/`
**Binary:** `mitm-transformer`
**Repository:** [github.com/Zheng-Bote/mitm_transformation](https://github.com/Zheng-Bote/mitm_transformation)

### Project Structure

```
mitm_transformation/
+-- cmd/transformer/main.go           Entrypoint, runner configuration
+-- internal/
|   +-- engine/
|   |   +-- engine.go                 Core pipeline orchestrator
|   |   +-- registry.go               String-to-function registry
|   |   +-- transform/library.go      Catalog of transform functions
|   |   +-- validate/library.go       Catalog of validation functions
|   +-- db/
|   |   +-- mapping_repo.go           Rules database loader
|   |   +-- raw_repo.go               Raw ingestion data access
|   |   +-- target_repo.go            Target fragment writes
|   +-- crypto/
|       +-- envelope.go               DEK/KEK encryption operations
+-- migrations/                       SQL DDL for mapping tables
```

### Mapping Data Model (SQL)

#### `mapping_source`

```sql
CREATE TABLE mapping_source (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    type        TEXT NOT NULL,     -- 'POSTGRES', 'ORACLE', 'CSV', 'KAFKA'
    version     INT DEFAULT 1,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

#### `mapping_target_field`

```sql
CREATE TABLE mapping_target_field (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic       TEXT NOT NULL,
    field_name  TEXT NOT NULL,
    data_type   TEXT NOT NULL,
    is_required BOOLEAN DEFAULT FALSE,
    encrypted   BOOLEAN DEFAULT FALSE,
    version     INT DEFAULT 1
);
```

#### `mapping_rule`

```sql
CREATE TABLE mapping_rule (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id          UUID REFERENCES mapping_source(id),
    target_field_id    UUID REFERENCES mapping_target_field(id),
    source_field       TEXT NOT NULL,
    priority           INT DEFAULT 0,
    transformation_chain JSONB DEFAULT '[]'::jsonb,
    validation_chain     JSONB DEFAULT '[]'::jsonb,
    version            INT DEFAULT 1
);
```

#### `topic_dependencies`

```sql
CREATE TABLE topic_dependencies (
    topic            VARCHAR(255) PRIMARY KEY,
    required_sources TEXT[] NOT NULL
);
```

### Transformation Chain Format (JSONB)

```json
[
  { "name": "trim_whitespace", "parameters": {} },
  {
    "name": "regex_replace",
    "parameters": { "pattern": "[^0-9\\.]", "replace": "" }
  },
  {
    "name": "parse_date",
    "parameters": { "input_format": "2006-01-02", "output_format": "RFC3339" }
  }
]
```

### Validation Chain Format (JSONB)

```json
[
  { "name": "not_null", "parameters": {} },
  {
    "name": "regex_match",
    "parameters": { "pattern": "^[a-zA-Z0-9._%+-]+@..." }
  },
  { "name": "range_check", "parameters": { "min": 0.0, "max": 1000000.0 } }
]
```

### Registry Pattern (Go Implementation)

```go
type TransformFunc func(val interface{}, params map[string]interface{}) (interface{}, error)
type ValidateFunc func(val interface{}, params map[string]interface{}) (bool, error)

type EngineRegistry struct {
    transforms map[string]TransformFunc
    validators map[string]ValidateFunc
}

// Built-in transforms
registry.transforms["trim_whitespace"] = trimWhitespace
registry.transforms["to_upper"]        = toUpper
registry.transforms["to_lower"]        = toLower
registry.transforms["default_value"]   = defaultValue
registry.transforms["regex_replace"]   = regexReplace
registry.transforms["parse_date"]      = parseDate
registry.transforms["string_split"]    = stringSplit
registry.transforms["cast_type"]       = castType

// Built-in validators
registry.validators["not_null"]    = notNull
registry.validators["regex_match"] = regexMatch
registry.validators["range_check"] = rangeCheck
registry.validators["email"]       = email
registry.validators["in_list"]     = inList
```

### Core Pipeline Engine Flow

1. Group pending `raw_ingestion` records by `correlation_id`, requiring all sources from `topic_dependencies`.
2. For each group:
   - Decrypt N raw payloads using DEK/KEK.
   - Merge into Golden Record (`map[string]interface{}`).
   - Load mapping rules for the topic.
   - For each target field: read source field, execute transformation chain, execute validation chain, encrypt if PII field.
   - Write to `target_fragments`, mark raw record as `processed`.
3. Validation failures go to `transformation_errors` (DLQ), raw records marked `failed_validation`.

### CLI Arguments

```bash
./mitm-transformer                          # Normal run
./mitm-transformer --retry-failed           # Retry failed validations
./mitm-transformer --workers 8              # Concurrent workers
```

### Target Fragments Table

```sql
CREATE TABLE target_fragments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic           VARCHAR(255) NOT NULL,
    correlation_id  UUID NOT NULL,
    payload         JSONB NOT NULL,
    delivery_status VARCHAR(50) DEFAULT 'pending',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### Transformation Errors Table

```sql
CREATE TABLE transformation_errors (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    correlation_id  UUID,
    failed_field    VARCHAR(255),
    rule_name       VARCHAR(255),
    error_message   TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 6. Delivery Layer

**Location:** `delivery-layer/mitm_delivery/`
**Binary:** `mitm-deliver`
**Repository:** [github.com/Zheng-Bote/mitm_delivery](https://github.com/Zheng-Bote/mitm_delivery)

### Project Structure

```
mitm_delivery/
+-- cmd/
|   +-- packager/        Package Creator entrypoint
|   +-- sender/          Delivery Sender entrypoint
+-- internal/
|   +-- packager/        Aggregation logic, idempotency key generation
|   +-- sender/          HTTP client, retry engine, adapter registry
|   +-- db/              PostgreSQL access (packages, DLQ, outbox)
|   +-- crypto/          Fragment decryption for packaging
+-- migrations/          SQL DDL for packages, DLQ, targets
+-- test/
    +-- mock_saas_test.go
```

### Database Schema

#### Packages Table (Outbox)

```sql
CREATE TABLE packages (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payload          JSONB NOT NULL,
    status           VARCHAR(50) DEFAULT 'pending',  -- pending, sending, delivered, failed
    retry_count      INT DEFAULT 0,
    idempotency_key  UUID NOT NULL UNIQUE,
    error_message    TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    delivered_at     TIMESTAMPTZ
);
```

#### Dead Letter Queue

```sql
CREATE TABLE dead_letter_queue (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id       UUID REFERENCES packages(id) ON DELETE SET NULL,
    payload          JSONB NOT NULL,
    error_code       VARCHAR(50),
    error_message    TEXT,
    failed_at        TIMESTAMPTZ DEFAULT NOW(),
    resolved         BOOLEAN DEFAULT FALSE,
    resolved_at      TIMESTAMPTZ
);
```

### Delivery Sender Interface (Go)

```go
type DeliverySender interface {
    Send(ctx context.Context, targetConfig TargetConfig,
         idempotencyKey string, payload []byte) (statusCode int, err error)
}
```

**Implemented adapters:**

- **Direct SaaS Adapter:** OAuth2 Client Credentials or static API Key.
- **APIGEE Gateway Adapter:** Mutual TLS (mTLS) with client certificates + JWT.

### Retry State Machine

```
pending -> sending -> delivered (success)
                    -> failed (transient) -> pending (after backoff) -> ...
                    -> failed_fatal (permanent) -> dead_letter_queue
```

Exponential backoff: 2s, 4s, 8s, 16s, 32s... (configurable multiplier).

### Delivery Workflow

**Phase 1 — Packaging:**

1. Select `target_fragments` where `delivery_status = 'pending'`.
2. Group by topic, generate `idempotency_key` (UUID v4).
3. Assemble JSON array payload, INSERT into `packages` (status `pending`).
4. UPDATE `target_fragments` set `delivery_status = 'packaged'`.

**Phase 2 — Delivery:**

1. SELECT from `packages` where `status = 'pending'` or retryable.
2. UPDATE status to `sending`.
3. Resolve target adapter from `delivery_targets` config.
4. HTTPS POST with `Idempotency-Key` header.
5. On 2xx: status `delivered`. On 429/503: backoff. On 400/401: DLQ.

---

## 7. Maintenance Layer

**Location:** `maintenance-layer/mitm_cleanup/`
**Binary:** `mitm_cleanup`
**Repository:** [github.com/Zheng-Bote/mitm_cleanup](https://github.com/Zheng-Bote/mitm_cleanup)

### Project Structure

```
mitm_cleanup/
+-- main.go                         Entrypoint
+-- internal/
|   +-- cleanup/
|   |   +-- orchestrator.go         Main cleanup loop
|   |   +-- pruning.go              Per-table DELETE queries
|   +-- db/connection.go            PostgreSQL pool
|   +-- ipc/client.go               Nil-safe IPC to scheduler
+-- go.mod + go.sum
```

### CLI Arguments (JSON via os.Args[1])

```json
{
  "target_fragments_retention_days": 7,
  "raw_ingestion_orphan_days": 14,
  "admin_audit_logs_retention_days": 90,
  "job_audit_logs_retention_days": 30,
  "system_logs_retention_days": 30,
  "job_status_events_retention_days": 14,
  "transformation_errors_retention_days": 30
}
```

### SQL Deletion Logic

```sql
DELETE FROM target_fragments WHERE delivery_status = 'delivered'
  AND created_at < NOW() - INTERVAL '7 days';

DELETE FROM raw_ingestion WHERE status IN ('completed', 'failed')
  AND created_at < NOW() - INTERVAL '14 days';

DELETE FROM system_logs WHERE created_at < NOW() - INTERVAL '30 days';

DELETE FROM dead_letter_queue WHERE resolved = TRUE
  AND resolved_at < NOW() - INTERVAL '90 days';
```

All deletions run within explicit database transactions. IPC events report progress.

---

## 8. Admin Frontend

**Location:** `admin-frontend/mitm_fe_cpp/`
**Build system:** CMake + Conan
**Framework:** C++23 with Qt6 (primary), Go/Fyne (alternative)

### C++ / Qt6 Project Structure

```
mitm_fe_cpp/
+-- CMakeLists.txt              Build configuration
+-- conanfile.txt               Conan dependencies
+-- conanfile_test.txt          Test-only dependencies
+-- src/                        C++ source files
+-- include/                    Header files
+-- configure/                  Build configuration scripts
+-- data/                       Icons, resources
+-- docs/                       Documentation
+-- img/                        Screenshots
+-- fix_headers.py              SPDX header normalization
+-- rewrite_widget.py           Qt widget code generation
```

### Qt6 UI Modules

| Module         | Purpose                                                         |
| :------------- | :-------------------------------------------------------------- |
| Dashboard      | System health overview, delivery metrics, DLQ alerts            |
| Job Manager    | CRUD for scheduled jobs, force-run, pause, log viewer           |
| Mapping Editor | Visual rule editor (QGraphicsScene node-based or nested tables) |
| DLQ Inspector  | Failed records table, payload viewer, requeue                   |
| Cursor Manager | Ingestion cursor listing, manual reset                          |
| Settings       | Target adapter config, MASTER_KEY input, certificates           |

### Authentication Flow

```
User launches app
  -> Enter auth token (masked field)
  -> Windows Hello biometric verification
  -> Token decrypted from Windows Credential Manager
  -> HELO handshake with Scheduler REST API
  -> Session established
```

All write operations require re-authentication via Windows Hello.

### REST API Calls (from frontend)

| Action          | Endpoint                                |
| :-------------- | :-------------------------------------- |
| Load jobs       | `GET /admin/jobs`                       |
| Create/edit job | `POST /admin/update-jobs`               |
| Delete job      | `POST /admin/delete-job`                |
| Force run       | `POST /admin/force-run`                 |
| View job logs   | `GET /admin/logs/job-status?run_id=...` |
| View DLQ        | `GET /api/v1/dlq`                       |
| Requeue DLQ     | `POST /api/v1/dlq/requeue`              |
| Upload CSV      | `POST /admin/upload/source_file`        |

---

## 9. Security Internals

### Envelope Encryption — Core Go Pattern

```go
const (
    KeySize   = 32          // AES-256
    NonceSize = 12          // Standard GCM nonce
)

// KEK from MASTER_KEY env var
kek, _ := base64.StdEncoding.DecodeString(os.Getenv("MASTER_KEY"))
block, _ := aes.NewCipher(kek)
aesGCM, _ := cipher.NewGCM(block)

// Generate DEK
dek := make([]byte, KeySize)
io.ReadFull(rand.Reader, dek)

// Wrap DEK with KEK (stored in storage_keys.wrapped_key)
nonce := make([]byte, NonceSize)
io.ReadFull(rand.Reader, nonce)
wrappedDEK := aesGCM.Seal(nil, nonce, dek, nil)

// Encrypt payload with DEK
payloadNonce := make([]byte, NonceSize)
io.ReadFull(rand.Reader, payloadNonce)
encryptedPayload := aesGCM.Seal(nil, payloadNonce, plaintextJSON, nil)
```

### Key Lifecycle

1. **Startup:** KEK loaded from `MASTER_KEY` env into RAM (never persisted).
2. **Collect:** DEK generated, payload encrypted, DEK wrapped with KEK, wrapped DEK stored in `storage_keys`, DEK zeroed from RAM.
3. **Transform:** Read wrapped DEK, unwrap with KEK, decrypt payload, process, re-encrypt, DEK zeroed from RAM.
4. **Deliver:** Unwrap DEK, decrypt, package JSON, send, DEK zeroed from RAM.
5. **Crypto-Shred:** `DELETE FROM storage_keys WHERE id = <target_dek_id>` — all associated data becomes permanently unreadable.

### Configuration File Encryption

Scheduler `config.json` encrypted with:

1. **Key derivation:** Argon2id (memory-hard).
2. **Encryption:** AES-256-GCM.
3. **Decryption:** Password from prompt or `SCHEDULER_PASSWORD` env var.

### Audit Logging

`admin_audit_logs` is **write-only** — no DELETE/UPDATE privileges granted to the application DB user. Immutable trail of admin logins, job mutations, key rotations, and config changes.

---

## 10. Appendix: Database Schemas & Migrations

### Migration Execution Order

```bash
# ===== SCHEDULER =====
psql -d mitm -f scheduler/mitm_scheduler/migrations/001_init.sql
psql -d mitm -f scheduler/mitm_scheduler/migrations/002_logging_and_audit.sql
psql -d mitm -f scheduler/mitm_scheduler/migrations/003_admin_and_api.sql
psql -d mitm -f scheduler/mitm_scheduler/migrations/004_add_name_unique.sql
psql -d mitm -f scheduler/mitm_scheduler/migrations/006_rbac.sql

# ===== COLLECTOR =====
psql -d mitm -f collector-layer/migrations/001_raw_ingestions.sql

# ===== TRANSFORMATION =====
psql -d mitm -f transformation-layer/migrations/001_mapping_source.sql
psql -d mitm -f transformation-layer/migrations/001_mapping_target_field.sql
psql -d mitm -f transformation-layer/migrations/001_mapping_transformation.sql
psql -d mitm -f transformation-layer/migrations/001_mapping_validation.sql
psql -d mitm -f transformation-layer/migrations/001_mapping_rule.sql
psql -d mitm -f transformation-layer/migrations/006_transformation_errors.sql
psql -d mitm -f transformation-layer/migrations/007_target_fragments.sql
psql -d mitm -f transformation-layer/migrations/008_topic_dependencies.sql

# ===== DELIVERY =====
psql -d mitm -f delivery-layer/migrations/001_packages.sql
psql -d mitm -f delivery-layer/migrations/002_dead_letter_queue.sql
psql -d mitm -f delivery-layer/migrations/003_packages_retry.sql
psql -d mitm -f delivery-layer/migrations/004_delivery_targets.sql
psql -d mitm -f delivery-layer/migrations/005_packages_topic.sql
```

### Complete Table Inventory

| #   | Table                    | Layer          | Purpose                                  |
| :-- | :----------------------- | :------------- | :--------------------------------------- |
| 1   | `scheduled_programs`     | Scheduler      | Job definitions with cron, command, args |
| 2   | `job_runs`               | Scheduler      | Execution history per job                |
| 3   | `system_logs`            | Scheduler      | Scheduler lifecycle events               |
| 4   | `job_status_events`      | Scheduler      | Real-time job progress (IPC)             |
| 5   | `job_audit_logs`         | Scheduler      | Audit messages from child jobs           |
| 6   | `admin_audit_logs`       | Scheduler      | Admin action audit trail                 |
| 7   | `http_config`            | Scheduler      | HTTP server configuration                |
| 8   | `admin_roles`            | Scheduler      | RBAC roles and permissions               |
| 9   | `storage_keys`           | Collector      | Wrapped DEK storage                      |
| 10  | `source_credentials`     | Collector      | Encrypted source configs                 |
| 11  | `raw_ingestion`          | Collector      | Encrypted raw data landing zone          |
| 12  | `ingestion_cursors`      | Collector      | Incremental extraction state             |
| 13  | `mapping_source`         | Transformation | Source system definitions                |
| 14  | `mapping_target_field`   | Transformation | Target field schemas                     |
| 15  | `mapping_rule`           | Transformation | Source-to-target field mappings          |
| 16  | `mapping_transformation` | Transformation | Transform function registry              |
| 17  | `mapping_validation`     | Transformation | Validation function registry             |
| 18  | `transformation_errors`  | Transformation | DLQ for validation failures              |
| 19  | `target_fragments`       | Transformation | Golden Records for delivery              |
| 20  | `topic_dependencies`     | Transformation | Multi-source join requirements           |
| 21  | `packages`               | Delivery       | JSON package outbox                      |
| 22  | `dead_letter_queue`      | Delivery       | Permanently failed deliveries            |
| 23  | `delivery_targets`       | Delivery       | Target adapter configurations            |

---

![ERD](erd_complete.png)

---

> **This technical overview was compiled from the README.md files, concept documents, and migration SQL files of each MitM project component.**
> For complete source code, refer to the individual Go repositories linked in each section.
