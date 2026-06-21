# Transformation Layer Documentation

The **Transformation Layer** (also referred to as the Orchestrator/Transformation Engine) acts as a **Stateful Aggregator**. It is responsible for reading raw ingested fragments from the database, grouping them by their deterministically generated `correlation_id` (waiting until all required sources have arrived), decrypting them, merging them into a Golden Record, applying mapping, transformation, and validation rules, encrypting the sensitive target fields, and writing the final data records to target tables (`target_fragments`).

**[Repo](https://github.com/Zheng-Bote/mitm_transformation)**

---

## 🏗️ Architecture & Pipeline

The Transformation Layer acts as an orchestration pipeline:

```mermaid
flowchart TD
    subgraph RawTable[Landing Zone]
        RAW[(PostgreSQL Raw Table)]
    end

    subgraph TransformationLayer[Transformation Layer]
        O[Orchestrator: Group by correlation_id] --> DEC[Decrypt N Raw Fragments]
        DEC --> MERGE[Merge Payloads into Golden Record]
        MERGE --> MAP[Load Mapping Rules]
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
        UUID correlation_id FK
        VARCHAR failed_field
        VARCHAR rule_name
        TEXT error_message
        TIMESTAMP created_at
    }

    topic_dependencies {
        VARCHAR topic PK
        TEXT[] required_sources
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

    raw_ingestion ||--o{ transformation_errors : "logs validation errors via correlation_id"
    mapping_source ||--o{ mapping_rule : "provides fields"
    mapping_target_field ||--o{ mapping_rule : "receives mapping"
```

### SQL Configurations & Schemas

The following configuration schemas define the mapping data model:

- [001_mapping_source.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_source.sql) - Configuration of raw source metadata structures.
- [001_mapping_target_field.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_target_field.sql) - Target schemas and fields definitions, indicating which fields are encrypted or required.
- [001_mapping_rule.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_rule.sql) - Core rule bindings linking source fields to target fields, listing transformation and validation chains.
- [001_mapping_transformation.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_transformation.sql) - Definitions of transformation functions (e.g., date formatting, string manipulation).
- [001_mapping_validation.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/001_mapping_validation.sql) - Definitions of validation rules (e.g., regex checks, value ranges, email format validation).
- [006_transformation_errors.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/006_transformation_errors.sql) - Dead Letter Queue (DLQ) tracking errors during processing.
- [007_target_fragments.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/007_target_fragments.sql) - The aggregated Golden Records stored securely.
- [008_topic_dependencies.sql](file:///home/zb_bamboo/DEV/__NEW__/Go/mitm-2/transformation-layer/migrations/008_topic_dependencies.sql) - Defines which source systems are required for a given topic before aggregation occurs.

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
    Note over O, RAW: Orchestration & Stateful Aggregation Phase
    O->>RAW: Fetch aggregated fragments (grouped by correlation_id, having required sources)
    RAW-->>O: Raw fragments arrays (encrypted payloads)

    O->>ENC: Decrypt N raw payloads with DEK
    ENC-->>O: Decrypted plaintext payloads
    O->>O: Merge N payloads into single Golden Record

    O->>RULES: Load mapping rules for topic & source
    RULES-->>O: Mapping rules, transformation & validation chains

    O->>TR: Apply transformation chain (transformation_chain)
    TR-->>O: Transformed values

    O->>VAL: Execute validation chain (validation_chain)
    VAL-->>O: Validation results (OK / Errors)

    O->>ENC: Encrypt sensitive target fields
    ENC-->>O: Encrypted ciphertext + nonce/metadata

    O->>TARGET: Write final aggregated record to target_fragments
    TARGET-->>O: DB Write Success
    end
```

## 🛠️ Implementation

The transformation engine is fully implemented in Go under the [`mitm_transformation`](./mitm_transformation) directory.
It operates as a **CLI Batch Job** orchestrated by a concurrent worker pool.

Key capabilities include:

- **Stateful Aggregation**: Groups and merges data from multiple independent source systems using deterministic Correlation IDs before transformation.
- **Rule Caching**: Rules are loaded from the database once per run.
- **Dead Letter Queue (DLQ)**: Failing validations are isolated without crashing the pipeline, and can be retried via the `--retry-failed` CLI flag.
- **Envelope Encryption**: Target fields marked as sensitive are encrypted on-the-fly using AES-256-GCM.
- **Concurrency**: High-throughput processing using row-level locking (`FOR UPDATE SKIP LOCKED` / `RETURNING`).
