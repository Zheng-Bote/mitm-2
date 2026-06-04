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
