# Configuration Guide: Employee Data Pipeline

This guide provides future administrators with a complete, step-by-step configuration tutorial to set up the data pipeline from Source to Delivery.
All examples are based on the `mirror-dev_employee` source database and the `Employee_mapping.csv` requirements.
You can configure the system either via the Admin Frontend UI or programmatically using the HTTP REST API. The concrete JSON requests for the API are documented below.

*Note: All API requests require a valid Basic Auth or Bearer token header (`Authorization`).*

---

## 1. Source System Configuration (Credentials)
First, define the source connection. This safely stores the encrypted connection strings for the collector.

**Endpoint:** `POST /admin/credentials`

**Payload:**
```json
{
  "source_name": "mirror-dev_employee",
  "connector_type": "POSTGRESQL",
  "config_payload": "{\n  \"host\": \"192.168.0.31\",\n  \"port\": 5432,\n  \"user\": \"db_user\",\n  \"password\": \"db_password\",\n  \"database\": \"mirror\"\n}",
  "is_active": true
}
```

---

## 2. Collector Setup (Scheduler Job)
Next, create a scheduled job to periodically collect raw data from the `employee` table.
The collector will use the `PERNR` column as an incremental cursor to only fetch new or updated records.

**Endpoint:** `POST /admin/update-jobs`

**Payload:**
```json
[
  {
    "id": "11111111-2222-3333-4444-555555555555",
    "source_name": "mirror-dev_employee",
    "topic": "Employee",
    "cron_expression": "0 0 * * *",
    "json_args": "{\"cursor_column\":\"PERNR\",\"source_name\":\"mirror-dev_employee\",\"table\":\"employee\",\"topic\":\"Employee\"}",
    "is_active": true
  }
]
```

---

## 3. Transformation Layer Configuration
The Transformation Layer maps the raw database columns into the final SaaS schema (`Demographics`).
This requires configuring the Source Metadata, Target Fields, and finally linking them via Rules.

### 3.1 Register Mapping Source
Register the raw source system in the transformation layer.

**Endpoint:** `POST /admin/transformation/sources`

**Payload:**
```json
{
  "id": "e0000000-0000-0000-0000-000000000001",
  "name": "mirror-dev_employee",
  "type": "postgresql"
}
```

### 3.2 Define Target Fields
Define the structure of your target system. Here we define `EmployeeNumber` and `SSNValue`. 
*(Note: You must repeat this API call for all required target fields like FirstName, LastName, DateOfBirth, etc.)*

**Endpoint:** `POST /admin/transformation/targets`

**Payload (Example 1: EmployeeNumber):**
```json
{
  "id": "f0000000-0000-0000-0000-000000000001",
  "topic": "Demographics",
  "field_name": "EmployeeNumber",
  "data_type": "string",
  "is_required": true,
  "encrypted": false
}
```

**Payload (Example 2: SSNValue - Encrypted):**
```json
{
  "id": "f0000000-0000-0000-0000-000000000002",
  "topic": "Demographics",
  "field_name": "SSNValue",
  "data_type": "string",
  "is_required": false,
  "encrypted": true
}
```

### 3.3 Define Transformations (Optional)
If you need to transform data (e.g. converting a date or changing text case), you must register the transformation logic first.

**Endpoint:** `POST /admin/transformation/transformations`

**Payload (Example: to_lowercase):**
```json
{
  "id": "t0000000-0000-0000-0000-000000000001",
  "name": "to_lowercase",
  "description": "Converts string to lowercase",
  "parameters": {}
}
```

**Payload (Example: to_iso_date):**
```json
{
  "id": "t0000000-0000-0000-0000-000000000002",
  "name": "to_iso_date",
  "description": "Parses custom date format to ISO-8601",
  "parameters": {
    "source_format": "DD.MM.RR"
  }
}
```

### 3.4 Define Validations (Optional)
Similarly, if you want to ensure data quality before delivery, register validation rules.

**Endpoint:** `POST /admin/transformation/validations`

**Payload (Example: not_null):**
```json
{
  "id": "v0000000-0000-0000-0000-000000000001",
  "name": "not_null",
  "description": "Rejects records where this field is empty",
  "parameters": {}
}
```

### 3.5 Create Mapping Rules
Finally, map the source columns to the target fields. You can optionally apply the transformation and validation chains you defined above.

**Endpoint:** `POST /admin/transformation/rules`

**Payload (Rule 1: PERNR -> EmployeeNumber):**
```json
{
  "source_id": "e0000000-0000-0000-0000-000000000001",
  "target_field_id": "f0000000-0000-0000-0000-000000000001",
  "source_field": "PERNR",
  "priority": 1,
  "transformation_chain": [],
  "validation_chain": [{"name": "not_null"}]
}
```

**Payload (Rule 2: SOCIALSECURITYNR -> SSNValue):**
```json
{
  "source_id": "e0000000-0000-0000-0000-000000000001",
  "target_field_id": "f0000000-0000-0000-0000-000000000002",
  "source_field": "SOCIALSECURITYNR",
  "priority": 1,
  "transformation_chain": [{"name": "trim"}],
  "validation_chain": []
}
```

*Repeat this pattern for the remaining fields (e.g. `BUSINESS_MAIL` -> `Email`, `COMPANYCODE` -> `Organization.Code`, etc.).*

### 3.6 Auto-Map (Smart Suggest)
Instead of creating Mapping Rules manually one by one, you can use the Auto-Map feature. By providing an array of raw source field names, the backend uses fuzzy string matching (Levenshtein distance) to automatically link them to the most likely target fields and generates the rules for you.

**Endpoint:** `POST /admin/transformation/auto-map`

**Payload:**
```json
{
  "source_id": "e0000000-0000-0000-0000-000000000001",
  "source_fields": ["PERNR", "SOCIALSECURITYNR", "FIRST_NAME", "LAST_NAME"]
}
```

---

## 4. Delivery Layer Setup
Once the transformation binary has processed the raw records, it stores the assembled JSON packages in the central PostgreSQL database (`delivery_outbox` / `packages` tables).

To actually transmit these packages to the external target (like a SaaS platform or an internal APIGEE API Gateway), you must configure a **Delivery Job** in the Scheduler. 

The Delivery Engine is highly interchangeable. You control routing (SaaS vs. APIGEE) entirely via the `json_args` passed to the scheduled job.

### 4.1 Delivery Job: Routing to Direct SaaS
This job runs every 5 minutes, picks up pending packages, and pushes them directly to the SaaS vendor using an API Key.

**Endpoint:** `POST /admin/update-jobs`

**Payload:**
```json
[
  {
    "id": "d1111111-2222-3333-4444-555555555555",
    "source_name": "delivery_engine",
    "topic": "Delivery_Demographics_SaaS",
    "cron_expression": "*/5 * * * *",
    "json_args": "{\"adapter\":\"SaaS\",\"endpoint_url\":\"https://api.saas-vendor.com/v1/ingest\",\"auth_type\":\"api_key\",\"api_key\":\"YOUR_SECURE_API_KEY\",\"batch_size\":500,\"retry_failed\":true}",
    "is_active": true
  }
]
```

### 4.2 Delivery Job: Routing to APIGEE Gateway
Alternatively, if your company policy requires routing traffic through an internal APIGEE API Gateway (e.g. using mTLS and a bearer token), you just configure a different adapter in `json_args`.

**Endpoint:** `POST /admin/update-jobs`

**Payload:**
```json
[
  {
    "id": "d2222222-2222-3333-4444-555555555555",
    "source_name": "delivery_engine",
    "topic": "Delivery_Demographics_APIGEE",
    "cron_expression": "*/5 * * * *",
    "json_args": "{\"adapter\":\"APIGEE\",\"endpoint_url\":\"https://gateway.internal.corp/mitm/v1/deliver\",\"auth_type\":\"mtls_jwt\",\"client_cert_path\":\"/certs/client.crt\",\"client_key_path\":\"/certs/client.key\",\"batch_size\":500,\"retry_failed\":true}",
    "is_active": true
  }
]
```

### 4.3 Error Handling & Retries
Regardless of the chosen adapter:
- Any delivery failures (e.g. HTTP 500 or Network Timeouts) are caught by the Delivery Engine and the package status remains `failed`. The engine uses exponential backoff for retries.
- Fatal errors (e.g. HTTP 400 Bad Request) are immediately routed to the **Dead Letter Queue (DLQ)** table to prevent blocking the queue.

