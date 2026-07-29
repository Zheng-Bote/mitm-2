# mitm_collector_employee_ora

## Overview
`mitm_collector_employee_ora` is a specialized Oracle data collector for the Man-in-the-Middle (MitM) Data Aggregator system. It is responsible for fetching employee data from an Oracle source database while simultaneously joining organizational data (`org` table) on the database level (`employee.departmentcode = org.short`). This ensures that the downstream Transformation and Delivery layers receive a single, denormalized payload per employee containing all required enrichment fields.

## Features
- Connects to an Oracle database using `godror`.
- Performs an inline `LEFT JOIN` between the primary configured table and the `org` table.
- Supports cursor-based incremental data fetching.
- Implements Envelope Encryption (AES-GCM) for data-at-rest.
- Communicates via Unix Domain Sockets for IPC logging and scheduler orchestration.

## Configuration
Requires `MITM_DB_CONFIG_JSON` or individual `MITM_DB_*` environment variables for connection. Invoked by the `mitm_scheduler` with JSON arguments to configure topics and table targets.

### Scheduler Parameters (JSON Arguments)
When the `mitm_scheduler` executes this collector, it passes a JSON configuration string as the first command-line argument (`os.Args[1]`). 

The following parameters are supported:

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `source_name` | string | No | The logical name of the source system (e.g., `mirror-dev_employee`). Defaults to `ORA_EMPLOYEE`. Must match a valid entry in the `source_credentials` DB table. |
| `table` | string | No | The primary Employee table to query from (e.g., `employee`). The `LEFT JOIN` onto the `org` table will use this table as its left side. Defaults to `employees`. |
| `cursor_column` | string | No | The numeric/incremental column used to track fetch progress (e.g., `id`). If set to `"none"`, the collector will fetch all rows without a cursor. |
| `topic` | string | No | The MitM system topic for downstream matching. Defaults to `ora.<table_name>.data`. |
| `business_key_column` | string | No | The unique column used to hash and generate the `correlation_id` (e.g., `PERNR`). Defaults to `id`. |

### Example Scheduler JSON
```json
{
  "source_name": "mirror-dev_employee",
  "table": "employee",
  "cursor_column": "none",
  "topic": "Employee",
  "business_key_column": "PERNR"
}
```
