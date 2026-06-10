/**
 * SPDX-FileComment: Collector Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_raw_ingestions.sql
 * @brief Migration script creating storage_keys, source_credentials, and raw_ingestion tables.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

-- Enable uuid-ossp extension if not already present
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table for Key Management (DEKs)
CREATE TABLE IF NOT EXISTS storage_keys (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wrapped_key  BYTEA NOT NULL,                 -- DEK encrypted with KEK
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    expires_at   TIMESTAMPTZ,                    -- For key rotation support
    is_active    BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE storage_keys IS 'Stores wrapped Data Encryption Keys (DEKs) for Envelope Encryption.';

-- Table for Source Credentials
CREATE TABLE IF NOT EXISTS source_credentials (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name     VARCHAR(100) NOT NULL UNIQUE, -- e.g., 'SAP_HR_PROD'
    connector_type  VARCHAR(50) NOT NULL,        -- e.g., 'REST_API', 'POSTGRESQL'
    topic           VARCHAR(100) NOT NULL,       -- e.g., 'Employee'
    
    -- Encrypted Connection Config
    config_payload  BYTEA NOT NULL,              -- AES-GCM encrypted JSON
    nonce           BYTEA NOT NULL,              -- 12-byte IV for AES-GCM
    dek_id          UUID NOT NULL,               -- Reference to storage_keys
    
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_dek_creds FOREIGN KEY (dek_id) REFERENCES storage_keys(id)
);

COMMENT ON TABLE source_credentials IS 'Stores connection details for source systems, encrypted with DEKs.';

-- RAW Ingestion Table (Landing Zone)
CREATE TABLE IF NOT EXISTS raw_ingestion (
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

COMMENT ON TABLE raw_ingestion IS 'Landing zone for raw encrypted data fragments.';

-- Index for efficient Orchestrator polling
CREATE INDEX IF NOT EXISTS idx_raw_pending_topics ON raw_ingestion (topic, status) WHERE status = 'pending';

-- Table for tracking ingestion cursors
CREATE TABLE IF NOT EXISTS ingestion_cursors (
    source_name  VARCHAR(100) PRIMARY KEY,
    last_cursor  VARCHAR(255) NOT NULL,
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE ingestion_cursors IS 'Tracks last processed data offset per source system.';

