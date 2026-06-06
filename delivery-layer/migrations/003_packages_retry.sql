/**
 * SPDX-FileComment: Delivery Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 003_packages_retry.sql
 * @brief Migration script to add next_retry_at to packages table.
 * @version 1.0.0
 * @date 2026-06-06
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

ALTER TABLE packages ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_packages_retry ON packages (status, next_retry_at) WHERE status = 'failed';
