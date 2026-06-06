# Transformation Layer Documentation

The **Transformation Layer** (also referred to as the Orchestrator/Transformation Engine) is responsible for reading raw ingested fragments from the database, decrypting them, applying mapping, transformation, and validation rules, encrypting the sensitive target fields, and writing the final data records to target tables.

---

## 🏗️ Architecture & Pipeline

The Transformation Layer acts as an orchestration pipeline:

```mermaid
flowchart TD
    subgraph RawTable[Landing Zone]
        RAW[(PostgreSQL Raw Table)]
    end

    subgraph TransformationLayer[Transformation Layer]
        O[Orchestrator] --> DEC[Decrypt Raw Data]
        DEC --> MAP[Load Mapping Rules]
        MAP --> TR[Transformation Engine]
        TR --> VAL[Validation Engine]
        VAL --> ENC2[Encrypt Target Fields]
    end

    subgraph DB[PostgreSQL Target]
        TARGET[(PostgreSQL Target Tables)]
    end

    RAW --> O
    ENC2 --> TARGET
```

---

## 📊 Mapping Data Model

The mapping system is modular, allowing you to define dynamic transformations and validation checks for different sources and target topics.

### Entity-Relationship Diagram (ERD)

```mermaid
erDiagram
    raw_ingestion {
        UUID id PK
        VARCHAR topic
        VARCHAR source_system
        UUID correlation_id
        BYTEA payload
        BYTEA nonce
        UUID dek_id
        VARCHAR status
        TIMESTAMP created_at
    }

    transformation_errors {
        UUID id PK
        UUID raw_ingestion_id FK
        VARCHAR failed_field
        VARCHAR rule_name
        TEXT error_message
        TIMESTAMP created_at
    }

    mapping_source {
        UUID id PK
        TEXT name
        TEXT type
        INT version
        TIMESTAMP created_at
    }

    mapping_target_field {
        UUID id PK
        TEXT topic
        TEXT field_name
        TEXT data_type
        BOOLEAN is_required
        BOOLEAN encrypted
        INT version
    }

    mapping_rule {
        UUID id PK
        UUID source_id FK
        UUID target_field_id FK
        TEXT source_field
        INT priority
        JSONB transformation_chain
        JSONB validation_chain
        INT version
    }

    mapping_transformation {
        UUID id PK
        TEXT name
        TEXT description
        JSONB parameters
        INT version
    }

    mapping_validation {
        UUID id PK
        TEXT name
        TEXT description
        JSONB parameters
        INT version
    }

    raw_ingestion ||--o{ transformation_errors : "logs validation errors"
    mapping_source ||--o{ mapping_rule : "provides fields"
    mapping_target_field ||--o{ mapping_rule : "receives mapping"
```

### SQL Configurations & Schemas

The following configuration schemas define the mapping data model:
*   [001_mapping_source.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_source.sql) - Configuration of raw source metadata structures.
*   [001_mapping_target_field.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_target_field.sql) - Target schemas and fields definitions, indicating which fields are encrypted or required.
*   [001_mapping_rule.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_rule.sql) - Core rule bindings linking source fields to target fields, listing transformation and validation chains.
*   [001_mapping_transformation.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_transformation.sql) - Definitions of transformation functions (e.g., date formatting, string manipulation).
*   [001_mapping_validation.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_validation.sql) - Definitions of validation rules (e.g., regex checks, value ranges, email format validation).
*   [002_transformation_errors.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/002_transformation_errors.sql) - Dead Letter Queue (DLQ) tracking errors during processing.

---

## 🔄 Runtime Flow

```mermaid
sequenceDiagram
    autonumber

    participant RAW as Raw Tables (PostgreSQL)
    participant O as Orchestrator / Engine
    participant ENC as Encryption Engine
    participant RULES as Mapping Rules (PostgreSQL)
    participant TR as Transformation Engine
    participant VAL as Validation Engine
    participant TARGET as Target Tables (PostgreSQL)

    %% Orchestrator Phase
    rect rgb(230, 240, 255)
    Note over O, RAW: Orchestration & Transformation Phase
    O->>RAW: Fetch pending raw fragments
    RAW-->>O: Raw fragments (encrypted payload)

    O->>ENC: Decrypt raw payload with DEK (unwrapped via KEK)
    ENC-->>O: Decrypted plaintext payload

    O->>RULES: Load mapping rules for topic & source
    RULES-->>O: Mapping rules, transformation & validation chains

    O->>TR: Apply transformation chain (transformation_chain)
    TR-->>O: Transformed values

    O->>VAL: Execute validation chain (validation_chain)
    VAL-->>O: Validation results (OK / Errors)

    O->>ENC: Encrypt sensitive target fields
    ENC-->>O: Encrypted ciphertext + nonce/metadata

    O->>TARGET: Write final records to target table
    TARGET-->>O: DB Write Success
    end
```

## 🛠️ Implementation

The transformation engine is fully implemented in Go under the [`mitm_transformation`](./mitm_transformation) directory. 
It operates as a **CLI Batch Job** orchestrated by a concurrent worker pool.

Key capabilities include:
- **Rule Caching**: Rules are loaded from the database once per run.
- **Dead Letter Queue (DLQ)**: Failing validations are isolated without crashing the pipeline, and can be retried via the `--retry-failed` CLI flag.
- **Envelope Encryption**: Target fields marked as sensitive are encrypted on-the-fly using AES-256-GCM.
- **Concurrency**: High-throughput processing using row-level locking (`FOR UPDATE SKIP LOCKED` / `RETURNING`).
