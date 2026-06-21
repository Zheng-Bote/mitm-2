# MitM Maintenance Layer (Clean-Up Job)

The **Maintenance Layer** is an essential part of the MitM Data Aggregator ecosystem. It is primarily responsible for enforcing data retention policies and ensuring GDPR compliance by securely deleting obsolete data.

## Overview

The `mitm_cleanup` standalone binary acts as a housekeeping job orchestrated by the central `mitm_scheduler`. It prevents the PostgreSQL database from unbounded growth by periodically purging:

- Processed or expired `raw_ingestion` fragments
- Successfully delivered `target_fragments`
- Old `packages` from the outbox
- Historical `system_logs` and `job_audit_logs`
- Expired `dead_letter_queue` (DLQ) entries

[repository](https://github.com/Zheng-Bote/mitm_cleanup)

## Configuration & Usage

The job is executed via the `mitm_scheduler`, which passes dynamic JSON arguments to dictate retention periods (in days). This allows granular control over how long different types of data are kept.

**Example Job Configuration (via API):**

```json
{
  "source_name": "maintenance_engine",
  "topic": "System_Cleanup",
  "cron_expression": "0 2 * * *",
  "json_args": "{\"retention_days_raw\": 7, \"retention_days_target\": 14, \"retention_days_logs\": 30, \"retention_days_audit\": 90}",
  "is_active": true
}
```

## Security

Just like all other components in the MitM project, the clean-up job connects to the database using credentials read from environment variables or secure inputs. The deletion operations explicitly respect database transaction boundaries.
