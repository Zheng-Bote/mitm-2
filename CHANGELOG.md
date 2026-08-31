# Changelog

All notable changes to the **Man-in-the-Middle (MitM) Data Aggregator** workspace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [MVP-2.10.0] - 2026-08-31

### Added / Changed
- **Spec-Driven Security Baseline**: Completed all open tasks from the `collector-layer.sdd`, `scheduler.sdd`, and `admin-frontend.sdd` SpecDD contracts to secure the architecture.
- **SQL Injection Prevention**: Replaced naive sanitization with a strict `validateIdentifier` allowlist logic for Oracle and PostgreSQL collector dynamic table and cursor queries.
- **Atomic Database Transactions**: Refactored Oracle database collectors to utilize batch transactions (`tx.Begin()` and `tx.Commit()`), perfectly aligning row ingestion and cursor updates in an atomic step.
- **Kafka Offset Safety**: Implemented transactional PostgreSQL boundaries in the Kafka collector, strictly enforcing that `CommitMessages()` is skipped if any PostgreSQL partial failure occurs.
- **Administrative RBAC Authorization**: Upgraded scheduler HTTP endpoints (e.g., `handleGetOsUserRoles`, `handleDLQ`) to use `requireAdmin(w, r)`, blocking unauthenticated or unprivileged access to administrative functionality.
- **Frontend Security**: Fixed use-after-free pointer risks in asynchronous update checks via Qt Smart Pointers (`QPointer`) and removed hardcoded fallback authentication tokens.
- **Frontend Security Roadmap (SpecDD)**: Extended `admin-frontend.sdd` with tasks #3–#12 covering OS input sanitization against path traversal, a centralized API client for uniform HTTP status/error handling, secure secret memory wiping, proxy credential hardening, role validation before sensitive UI actions, dependency pinning (QXlsx), CTest/CI pipelines, SBOM lockfiles with vulnerability scanning, and consolidated secret management.
- **Database**: Added the missing delivery migrations `006_fix_dlq_fk.sql` (removes the `ON DELETE SET NULL` foreign key from `dead_letter_queue`) and `007_adapter_tokens.sql` (new `adapter_tokens` table) to the central `migrations/setup.sql`.
- **Documentation**: Added `delivery-layer/docs/dlq_requeue_flow.md` describing the architectural DLQ requeue flow across Admin Frontend, Scheduler, and Delivery Layer, including its atomic PostgreSQL transaction (Scenario A package update / Scenario B package recovery).

## [MVP-2.9.0] - 2026-08-29

### Added / Changed
- **Documentation**: Comprehensive synchronization of all `README.md` and `CHANGELOG.md` files across the repository. The `./docs/*` directory is now fully consistent with the component-level documentation. Added "Key Architectural Principles" to the root README.
- **System Architecture Alignment**: Resolved all findings from the recent code quality and security analysis to align the codebase 100% with `architecture.md`:
  - **Atomicity**: Implemented `pgx.Batch` across all data collectors for transactional safety.
  - **Security**: Added strict 32-byte length validation for Envelope Encryption KEKs and `subtle.ConstantTimeCompare` for Basic Auth.
  - **Resilience**: Added context cancellations (`signal.NotifyContext`) for graceful shutdown on `SIGTERM`/`SIGINT`.
  - **Resource Management**: Enforced `pgxpool` limits (`MaxConns`, `MaxConnLifetime`) to protect the PostgreSQL storage layer.
  - **Observability**: Implemented DLQ error tracking and propagated failure metrics via IPC sockets to the Scheduler.
- **Delivery Layer**: Bumped `mitm_delivery` version to `v0.18.0`.

## [MVP-2.8.0] - 2026-08-09

### Added 
- **Backup/Restore**: New role BACKUP-RESTORE and Methods for C++ Frontend and Webserver

### Fixed
- **SaaS_Cority Delivery***: Fixed DLQ for "Bad Gateway" error

## [MVP-2.7.0] - 2026-07-29

### Added
- **Delivery Layer**: Implemented configurable `slowdown` and `timeout` parameters for the `CORITY_SAAS` delivery adapter.

### Changed
- **Database**: Synced PostgreSQL database schema IST-Zustand across all layer `.sql` migrations (`setup.sql`, `transformation-layer`, `delivery-layer`, `scheduler`).
- **Components Logging**: Refactored component version logging mechanism across all layers (Collectors, Transformation, Delivery, Scheduler) to consistently output a clean `Major.Minor.Patch` version format.

### Fixed
- **Scheduler**: Resolved an HTTP 500 error on the `/admin/transformation/errors_bin` API endpoint by updating the query to correctly reference the `raw_ingestion_id` column and gracefully handle null values.

## [MVP-2.6.0] - 2026-06-21

### Added
- **Maintenance Layer**: Created the `mitm_cleanup` module to systematically purge historical logs (system/audit), successfully delivered fragments, packages, and dead letter queue entries based on dynamic JSON retention parameters (`retention_days`).
- **End-to-End Test Suite**: Implemented `test_e2e.sh` orchestration script and a dedicated `mock_saas` server. Fully verified the architectural data flow from source ingestion (CSV) through the Transformation layer to secure SaaS Delivery.
- **Delivery Layer Fallbacks**: Introduced mock development fallbacks for handling key-rotation disruptions during local end-to-end execution.

### Fixed
- **Database Schema Constraints**: Resolved structural foreign key conflicts (`raw_ingestion_id` vs `correlation_id`) in target insertion routines and error tables.

## [MVP-2.5.0] - 2026-06-15
### Added
- **Centralized Application Telemetry**: Defined global application names, descriptions, and versions across all ecosystem components (Scheduler, Collectors, Transformation, Delivery).
- **Startup IPC Logging**: All components now automatically broadcast their name and version via Unix Domain Sockets (`IPCClient`) on initialization.
- **Dynamic Scheduler Versioning**: Added `ldflags` support to the Scheduler to allow compile-time overriding of the version variable (`-X main.version=$MITM_SERVER`).
- **Validation Engine**: Expanded the transformation rules library with `min_length` and `max_length` validators.
- **SaaS Audit Trails**: The Delivery Cority SaaS adapter now captures and logs the complete, raw HTTP response payload into the central `job_audit_log` table.

## [MVP-2.4.0] - 2026-06-09

### Added
- **Admin Frontend (C++ Qt)**: Introduced Auto-Map (Smart Suggest) for Transformation rules using Levenshtein distance matching. Added a "details" column to Admin Logs.
- **Scheduler (Go)**: Added REST endpoint `/admin/transformation/auto-map` to calculate mapping suggestions.
- **Documentation**: Created `data/example.md` and `data/example_config.sql` for Employee mappings. Updated `architecture.md` and `concept_mitm_aggregator.md` to formally document the Qt Admin Frontend.

### Fixed
- **Admin Frontend**: Fixed an issue where the Status Bar was cleared when opening the "About" dialog.
- **Transformation Layer**: Fixed a bug where `json_parse` failed because `raw_ingestion.payload` was not decrypted. Added `EnvelopeDecrypt` logic in the Transformer worker before JSON parsing.

## [MVP-2.3.0] - 2026-06-06

### Changed
- **Environment-based Credentials**: The entire ecosystem (Scheduler, Collectors, Transformation, Delivery) has been migrated to pass MitM Database credentials via environment variables (`MITM_DB_HOST`, `MITM_DB_PORT`, etc.) instead of command-line arguments.
- **Job Arguments Refactoring**: CLI job overrides are now universally passed via `os.Args[1]` across all modules since the database configuration argument has been removed.

## [MVP-2.2.0] - 2026-06-05

### Added
- **Dynamic Ingestion (Schema-Agnostic)**: Both PostgreSQL and Oracle collectors rewritten to retrieve dynamic columns and data types using `rows.FieldDescriptions()` / `rows.Values()` and standard SQL column scan patterns.
- **Dynamic Routing Overrides**: Added support in both collectors for scheduler JSON overrides (`source_name`, `table`, `cursor_column`, and target `topic`) passed via `os.Args[1]`.
- **JSONB Scheduler Arguments**: Migrated the scheduled programs arguments column in PostgreSQL to `JSONB` via migration `005_change_args_to_jsonb.sql`.
- **GUI Input Validation**: Integrated automatic JSON schema checks on job arguments within the `scheduler-admin` Fyne utility.
- **Developer Documentation**: Created [collector_creation_guide.md](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/collector-layer/collector_creation_guide.md) to detail dynamic collector implementation guidelines.

### Changed
- Replaced hardcoded `Employee` struct in collectors with dynamic mapping serialization to JSON.
- Standardized cursor persistence to string-based cursor values (`maxCursorValue`) in `ingestion_cursors`.

## [MVP-2.1.0] - 2026-06-04

### Added
- **Oracle Collector**: Introduced Oracle database support via the `mitm_collector_ora-employee` package.
- **Log Downloads**: Added backend REST endpoints and GUI download features in the scheduler for system logs, status events, and job audit logs.
- **Authentication**: Added HELO security handshake for remote scheduler API calls.

### Changed
- Restored original v0.1.0 CLI parameters to ensure scheduler-collector coordination.

## [MVP-2.0.0] - 2026-06-03

### Added
- **Architecture and Concept Specifications**: Added `architecture.md` (arc42-based concept) and `concept_mitm_aggregator.md`.
- **MitM Scheduler**: Built the central daemon utilizing standard cron expressions for scheduling collector executions.
- **PostgreSQL Collector**: Built the initial `mitm_collector_pg-employee` utilizing AES-GCM envelope encryption (wrapping storage DEKs with master KEK).
- **IPC Logging**: Developed Unix Domain Socket IPC for real-time status and audit reporting from jobs.
