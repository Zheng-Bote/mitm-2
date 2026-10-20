/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 010_raw_ingestion_correlation_index.sql
 * @brief Migration script adding an index on raw_ingestion for per-correlation_id lookups.
 * @version 1.0.0
 * @date 2026-10-19
 *
 * @author ZHENG Robert (robert@hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

-- The transformation job looks up fragments per (topic, correlation_id) including status 'processed'
-- (claim HAVING subquery, claim UPDATE, load_counterparts). idx_raw_pending_topics only covers
-- status 'pending', so these lookups were sequential scans over the whole table per aggregate.
-- (source_system, created_at DESC) serve COUNT(DISTINCT source_system) and the DISTINCT ON ordering.
CREATE INDEX IF NOT EXISTS idx_raw_topic_correlation
    ON raw_ingestion (topic, correlation_id, status, source_system, created_at DESC)
    WHERE correlation_id IS NOT NULL;

ANALYZE raw_ingestion;
