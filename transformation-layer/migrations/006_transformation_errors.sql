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
