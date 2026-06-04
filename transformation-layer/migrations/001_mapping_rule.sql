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
