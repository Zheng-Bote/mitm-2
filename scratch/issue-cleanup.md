## Feature Intent

Expand the `mitm_maintenance_cleanup` batch job to clean up additional operational database tables that grow indefinitely over time, and introduce a generic mechanism for time-based filesystem cleanup (e.g. for upcoming Medical Device image chunks).

## Requirements (EARS Syntax)

1. The system shall delete records from `program_runs` older than a configurable number of days.
2. The system shall delete records from `packages` (with status 'delivered') older than a configurable number of days.
3. The system shall delete records from `dead_letter_queue` (where `resolved = true`) older than a configurable number of days.
4. The system shall continue to delete records from `raw_ingestion` as defined by existing configurations.
5. While executing the cleanup job, if configured with filesystem directory paths and retention periods, the system shall recursively delete files in those directories older than the specified age.

## Scope

- Maintenance Layer: `mitm_maintenance_cleanup`
- Root config templates (JSON cleanup arguments).

## SpecDD Architecture Alignment (Drift Control)

Please confirm that this feature respects the global `mitm-2` constraints defined in `.sdd` files:

- [x] **Architecture:** The layered architecture is maintained (no direct bypass from Collector to Delivery).
- [x] **Architecture:** Feature affects architecture: SpecKit feature forces update of the SpecDD .sdd
- [x] **Security:** Envelope Encryption (AES-GCM) is NOT bypassed for PII data.
- [x] **Data Model:** Core PostgreSQL schemas remain intact (feature-specific tables are allowed).
- [x] **Standards:** SPDX headers, English documentation, and independent `go.mod` (or Cargo.toml) per layer will be maintained.

## Acceptance Criteria

- [ ] JSON arguments extended for `program_runs_retention_days`, `packages_retention_days`, `dlq_resolved_retention_days`, and a new `fs_cleanup_rules` structure.
- [ ] Database cleanup logic implemented for the 3 missing tables + existing `raw_ingestion`.
- [ ] Generic filesystem cleanup logic implemented (reading modified time, applying retention).
- [ ] Unit/Integration tests updated.
- [ ] CHANGELOG.md and README.md are up-to-date.
