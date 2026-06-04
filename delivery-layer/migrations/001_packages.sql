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
