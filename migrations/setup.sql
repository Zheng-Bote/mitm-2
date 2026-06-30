-- ==========================================
-- Source: collector-layer/migrations/001_raw_ingestions.sql
-- ==========================================
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



-- ==========================================
-- Source: delivery-layer/migrations/001_packages.sql
-- ==========================================
/**
 * SPDX-FileComment: Delivery Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_packages.sql
 * @brief Migration script creating packages table for delivery tracking.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS packages (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payload          JSONB NOT NULL,                 -- Aggregated data package ready to be sent
    status           VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'sending', 'delivered', 'failed'
    retry_count      INT DEFAULT 0,
    idempotency_key  UUID NOT NULL UNIQUE,           -- To ensure SaaS idempotency
    error_message    TEXT,                           -- Error description in case of failure
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    delivered_at     TIMESTAMPTZ
);

COMMENT ON TABLE packages IS 'Stores assembled data packages and tracks delivery state.';

CREATE INDEX IF NOT EXISTS idx_packages_status ON packages (status) WHERE status = 'pending';


-- ==========================================
-- Source: delivery-layer/migrations/002_dead_letter_queue.sql
-- ==========================================
/**
 * SPDX-FileComment: Delivery Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 002_dead_letter_queue.sql
 * @brief Migration script creating dead_letter_queue table for failed package storage.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS dead_letter_queue (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id       UUID REFERENCES packages(id) ON DELETE SET NULL,
    payload          JSONB NOT NULL,                 -- Copy of the failed package/data payload
    error_code       VARCHAR(50),                    -- E.g., 'HTTP_400', 'TRANSFORMATION_ERROR'
    error_message    TEXT,                           -- Details of why it was moved to DLQ
    failed_at        TIMESTAMPTZ DEFAULT NOW(),
    resolved         BOOLEAN DEFAULT FALSE,
    resolved_at      TIMESTAMPTZ
);

COMMENT ON TABLE dead_letter_queue IS 'Stores failed packages for troubleshooting and replay.';

CREATE INDEX IF NOT EXISTS idx_dlq_unresolved ON dead_letter_queue (resolved) WHERE resolved = FALSE;


-- ==========================================
-- Source: delivery-layer/migrations/003_packages_retry.sql
-- ==========================================
/**
 * SPDX-FileComment: Delivery Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 003_packages_retry.sql
 * @brief Migration script to add next_retry_at to packages table.
 * @version 1.0.0
 * @date 2026-06-06
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

ALTER TABLE packages ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_packages_retry ON packages (status, next_retry_at) WHERE status = 'failed';


-- ==========================================
-- Source: delivery-layer/migrations/004_delivery_targets.sql
-- ==========================================
/**
 * SPDX-FileComment: MitM Aggregator Delivery Targets
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 004_delivery_targets.sql
 * @brief Migration script creating delivery_targets table.
 *
 * @author ZHENG Robert (robert@hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @LICENSE Apache-2.0
 */

CREATE TABLE IF NOT EXISTS delivery_targets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic           VARCHAR(100) NOT NULL UNIQUE, -- e.g., 'Employee'
    adapter_type    VARCHAR(50) NOT NULL,         -- e.g., 'CORITY_SAAS', 'APIGEE'
    endpoint_url    TEXT NOT NULL,                -- e.g., 'https://.../api/employeeimport'
    
    -- Encrypted Config (Credentials + Options)
    config_payload  BYTEA NOT NULL,               -- AES-GCM encrypted JSON
    nonce           BYTEA NOT NULL,               -- 12-byte IV for AES-GCM
    dek_id          UUID NOT NULL REFERENCES storage_keys(id),
    
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE delivery_targets IS 'Stores connection details and metadata for target systems, encrypted with DEKs.';


-- ==========================================
-- Source: delivery-layer/migrations/005_packages_topic.sql
-- ==========================================
/**
 * SPDX-FileComment: Add topic to packages
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 */

ALTER TABLE packages ADD COLUMN IF NOT EXISTS topic VARCHAR(255) DEFAULT 'default';
CREATE INDEX IF NOT EXISTS idx_packages_topic_status ON packages (topic, status);


-- ==========================================
-- Source: scheduler/migrations/000_db.sql
-- ==========================================
-- Database: mitm

-- DROP DATABASE IF EXISTS mitm;

CREATE DATABASE mitm
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

COMMENT ON DATABASE mitm
    IS 'Man in the Middle Data Agregator';

GRANT TEMPORARY, CONNECT ON DATABASE mitm TO PUBLIC;

GRANT ALL ON DATABASE mitm TO mitm_user;

GRANT ALL ON DATABASE mitm TO postgres;

-- ==========================================
-- Source: scheduler/migrations/001_init.sql
-- ==========================================
-- 001_init.sql

-- Table for scheduled programs (jobs)
CREATE TABLE IF NOT EXISTS scheduled_programs (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    command TEXT NOT NULL,
    args JSONB DEFAULT '{}'::jsonb,
    cron_expr TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    restart_on_exit BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Table for tracking program execution runs
CREATE TABLE IF NOT EXISTS program_runs (
    id SERIAL PRIMARY KEY,
    program_id INT REFERENCES scheduled_programs(id) ON DELETE CASCADE,
    pid INT,
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,
    exit_code INT,
    success BOOLEAN
);

-- Table for IPC status events from jobs
CREATE TABLE IF NOT EXISTS job_status_events (
    id SERIAL PRIMARY KEY,
    run_id INT REFERENCES program_runs(id) ON DELETE CASCADE,
    status TEXT,
    message TEXT,
    progress INT,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Table for global scheduler configuration
CREATE TABLE IF NOT EXISTS scheduler_config (
    id SERIAL PRIMARY KEY,
    http_port INT DEFAULT 8080,
    socket_path TEXT DEFAULT '/tmp/scheduler.sock'
);

-- Insert default config if not exists
INSERT INTO scheduler_config (http_port, socket_path)
SELECT 8080, '/tmp/scheduler.sock'
WHERE NOT EXISTS (SELECT 1 FROM scheduler_config);


-- ==========================================
-- Source: scheduler/migrations/002_logging_and_audit.sql
-- ==========================================
-- 002_logging_and_audit.sql

-- Table for core scheduler system logs
CREATE TABLE IF NOT EXISTS system_logs (
    id SERIAL PRIMARY KEY,
    level TEXT NOT NULL, -- DEBUG, INFO, ERROR
    component TEXT NOT NULL, -- Scheduler, HTTP, IPC, etc.
    message TEXT NOT NULL,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Table for job audit logs
CREATE TABLE IF NOT EXISTS job_audit_logs (
    id SERIAL PRIMARY KEY,
    run_id INT REFERENCES program_runs(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add log_level to scheduler_config
ALTER TABLE scheduler_config ADD COLUMN IF NOT EXISTS log_level TEXT DEFAULT 'INFO';


-- ==========================================
-- Source: scheduler/migrations/003_admin_and_api.sql
-- ==========================================
-- 003_admin_and_api.sql

-- Table for administrative users
CREATE TABLE IF NOT EXISTS admin_users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL, -- Scrypt or Argon2 hash
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Note: We'll need a way to bootstrap an admin user.
-- For now, we'll use a simple "HELO" token in the config for demonstration,
-- but the table is ready for a full RBAC system.

-- Table for audit of administrative actions
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    action TEXT NOT NULL,
    details JSONB,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);


-- ==========================================
-- Source: scheduler/migrations/003_job_audit_logs_component.sql
-- ==========================================
/**
 * SPDX-FileComment: Job Audit Logs Component
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 */

ALTER TABLE job_audit_logs ADD COLUMN IF NOT EXISTS component VARCHAR(255) DEFAULT 'Scheduler';


-- ==========================================
-- Source: scheduler/migrations/004_add_name_unique.sql
-- ==========================================
-- 004_add_name_unique.sql

-- Drop the constraint if it exists to avoid errors on duplicate application
ALTER TABLE scheduled_programs DROP CONSTRAINT IF EXISTS scheduled_programs_name_key;

-- Add a unique constraint to the 'name' column in 'scheduled_programs' table
-- to support INSERT ... ON CONFLICT (name) syntax.
ALTER TABLE scheduled_programs ADD CONSTRAINT scheduled_programs_name_key UNIQUE (name);


-- ==========================================
-- Source: scheduler/migrations/005_change_args_to_jsonb.sql
-- ==========================================
/**
 * SPDX-FileComment: Migrate scheduled_programs.args to JSONB
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 005_change_args_to_jsonb.sql
 * @brief Migration script changing scheduled_programs.args column to JSONB.
 * @version 1.0.0
 * @date 2026-06-05
 *
 * @author ZHENG Robert (robert@hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

ALTER TABLE scheduled_programs DROP COLUMN IF EXISTS args;
ALTER TABLE scheduled_programs ADD COLUMN args JSONB DEFAULT '{}'::jsonb;


-- ==========================================
-- Source: scheduler/migrations/006_rbac.sql
-- ==========================================
-- 006_rbac.sql

-- Table for roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Default roles
INSERT INTO roles (name, description) VALUES
('ADMIN', 'Full access to all system features'),
('VIEWER', 'Read-only access to monitoring and logs'),
('UPLOADER', 'Access to manual file upload mechanisms (CSV/XLSX)')
ON CONFLICT (name) DO NOTHING;

-- Table for user roles (encrypted assignment)
-- Zuordnung von Rollen zu Usern soll manipulationssicher in der Datenbank verschlüsselt werden
CREATE TABLE IF NOT EXISTS user_roles_encrypted (
    user_id INT PRIMARY KEY REFERENCES admin_users(id) ON DELETE CASCADE,
    wrapped_dek BYTEA NOT NULL,
    nonce BYTEA NOT NULL,
    encrypted_roles BYTEA NOT NULL, -- Encrypted JSON array of role IDs
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);


-- ==========================================
-- Source: transformation-layer/migrations/001_mapping_source.sql
-- ==========================================
/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_mapping_source.sql
 * @brief Migration script creating mapping_source table.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS mapping_source (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,              -- Oracle_HR, SAP_HCM, CSV_Employees
    type TEXT NOT NULL,              -- oracle, csv, api, kafka
    topic TEXT NOT NULL,             -- Employee, Department, etc.
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

COMMENT ON TABLE mapping_source IS 'Defines metadata structure configurations for raw sources.';


-- ==========================================
-- Source: transformation-layer/migrations/002_mapping_target_field.sql
-- ==========================================
/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_mapping_target_field.sql
 * @brief Migration script creating mapping_target_field table.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS mapping_target_field (
    id UUID PRIMARY KEY,
    topic TEXT NOT NULL,             -- Employee, Organization, GEO
    field_name TEXT NOT NULL,        -- last_name, birth_date, country_code
    data_type TEXT NOT NULL,         -- text, int, date, jsonb
    is_required BOOLEAN NOT NULL,
    encrypted BOOLEAN NOT NULL DEFAULT false,
    version INT NOT NULL DEFAULT 1
);

COMMENT ON TABLE mapping_target_field IS 'Defines target schemas and field constraints, listing required and encrypted fields.';


-- ==========================================
-- Source: transformation-layer/migrations/003_mapping_rule.sql
-- ==========================================
/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_mapping_rule.sql
 * @brief Migration script creating mapping_rule table.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS mapping_rule (
    id UUID PRIMARY KEY,
    source_id UUID NOT NULL REFERENCES mapping_source(id),
    target_field_id UUID NOT NULL REFERENCES mapping_target_field(id),
    source_field TEXT NOT NULL,      -- z.B. "EMP.LASTNAME"
    priority INT NOT NULL DEFAULT 1, -- falls mehrere Quellen dasselbe Feld liefern
    transformation_chain JSONB NULL, -- Liste von Transformationen
    validation_chain JSONB NULL,     -- Liste von Validierungen
    version INT NOT NULL DEFAULT 1
);

COMMENT ON TABLE mapping_rule IS 'Binds source fields to target fields, applying validation and transformation chains.';


-- ==========================================
-- Source: transformation-layer/migrations/004_mapping_transformation.sql
-- ==========================================
/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_mapping_transformation.sql
 * @brief Migration script creating mapping_transformation table.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS mapping_transformation (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,              -- trim, to_int, normalize_date
    description TEXT,
    parameters JSONB NULL,           -- z.B. {"format": "YYYY-MM-DD"}
    version INT NOT NULL DEFAULT 1
);

COMMENT ON TABLE mapping_transformation IS 'Defines transformation functions for data values.';


-- ==========================================
-- Source: transformation-layer/migrations/005_mapping_validation.sql
-- ==========================================
/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_mapping_validation.sql
 * @brief Migration script creating mapping_validation table.
 * @version 1.0.0
 * @date 2026-06-04
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS mapping_validation (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,              -- not_null, regex, range
    description TEXT,
    parameters JSONB NULL,           -- {"min":0,"max":120}
    version INT NOT NULL DEFAULT 1
);

COMMENT ON TABLE mapping_validation IS 'Defines validation functions for data values.';


-- ==========================================
-- Source: transformation-layer/migrations/006_transformation_errors.sql
-- ==========================================
/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 002_transformation_errors.sql
 * @brief Migration script creating transformation_errors table for DLQ.
 * @version 1.0.0
 * @date 2026-06-05
 *
 * @author ZHENG Robert (robert@hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS transformation_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    correlation_id UUID NOT NULL,
    failed_field VARCHAR(255) NOT NULL,
    rule_name VARCHAR(100) NOT NULL,
    error_message TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE transformation_errors IS 'Dead Letter Queue (DLQ) tracking transformation and validation errors for raw ingestion records.';


-- ==========================================
-- Source: transformation-layer/migrations/007_target_fragments.sql
-- ==========================================
/**
 * SPDX-FileComment: Target Fragments Table
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 007_target_fragments.sql
 * @brief Migration script creating generic target_fragments table.
 */

CREATE TABLE IF NOT EXISTS target_fragments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    correlation_id UUID NOT NULL,
    topic VARCHAR(255) NOT NULL,
    payload_jsonb JSONB NOT NULL,
    delivery_status VARCHAR(50) DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_target_fragments_topic ON target_fragments(topic);
CREATE INDEX IF NOT EXISTS idx_target_fragments_status ON target_fragments(delivery_status);


-- ==========================================
-- Source: transformation-layer/migrations/008_topic_dependencies.sql
-- ==========================================
/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 008_topic_dependencies.sql
 * @brief Migration script creating topic_dependencies table.
 */

CREATE TABLE IF NOT EXISTS topic_dependencies (
    topic VARCHAR(255) PRIMARY KEY,
    required_sources TEXT[] NOT NULL
);

COMMENT ON TABLE topic_dependencies IS 'Defines which source systems are required before a topic can be aggregated.';


