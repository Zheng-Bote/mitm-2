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
