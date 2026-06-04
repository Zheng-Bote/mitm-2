# Collector Layer Concept: Encrypted RAW Ingestion

## Overview
The Collector Layer consists of independent Go programs responsible for fetching data from various source systems (APIs, SQL, CSV) and storing it in a central PostgreSQL **RAW Table**. 

To ensure security and compliance (GDPR/PII), all sensitive data is protected using **Envelope Encryption** (AES-GCM) before it hits the database.

## Security Architecture: Envelope Encryption
Following the project's security standards, we use a two-tier key hierarchy:
1.  **Master Key (KEK):** Resides only in the RAM of the Go processes (provided via environment variables). It is never persisted.
2.  **Data Encryption Keys (DEKs):** Unique keys generated for data encryption. These are stored in the database but are "wrapped" (encrypted) by the KEK.

## Database Schema

### 1. Key Management (`storage_keys`)
Stores the encrypted DEKs.

```sql
CREATE TABLE storage_keys (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wrapped_key  BYTEA NOT NULL,                 -- DEK encrypted with KEK
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

## Workflow

### Collector Process
1.  **Initialize:** Load Master Key (KEK) from environment.
2.  **Fetch Credentials:** 
    *   Query `source_credentials` for the specific `source_name`.
    *   Retrieve the referenced `wrapped_key` from `storage_keys`.
    *   Unwrap DEK using KEK.
    *   Decrypt `config_payload` using DEK and `nonce`.
3.  **Ingest Data:** Use decrypted credentials to connect to the source and fetch data.
4.  **Encrypt & Store:**
    *   Generate a fresh 12-byte `nonce`.
    *   Encrypt the data fragment using the DEK (or a fresh DEK).
    *   Insert record into `raw_ingestion`.

### Orchestrator Process
1.  **Poll:** Select `pending` records from `raw_ingestion`.
2.  **Decrypt:** Retrieve DEK (unwrap with KEK) and decrypt the `payload`.
3.  **Process:** Transform, aggregate, and prepare for target delivery.
4.  **Update:** Set `status` to `completed` and set `processed_at`.

## Benefits
*   **Security:** Data is never stored in plaintext. Even DB administrators cannot read it without the KEK.
*   **Decoupling:** Collectors don't need to know the final destination; they just "dump and run" into the RAW table.
*   **Traceability:** `correlation_id` and `source_system` allow for clear audit trails.
*   **Compliance:** "Crypto-shredding" is possible by deleting the specific DEK for a source or time range.
