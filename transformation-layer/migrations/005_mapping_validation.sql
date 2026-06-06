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
