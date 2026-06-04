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
