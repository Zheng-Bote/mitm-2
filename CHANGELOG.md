# Changelog

All notable changes to the **Man-in-the-Middle (MitM) Data Aggregator** workspace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
