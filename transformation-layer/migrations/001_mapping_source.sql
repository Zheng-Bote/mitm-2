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
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

COMMENT ON TABLE mapping_source IS 'Defines metadata structure configurations for raw sources.';
