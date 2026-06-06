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
