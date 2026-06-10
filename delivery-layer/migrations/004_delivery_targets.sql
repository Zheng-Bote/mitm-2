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
