/**
 * SPDX-FileComment: Delivery Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 006_fix_dlq_fk.sql
 * @brief Migration script to remove ON DELETE SET NULL foreign key from dead_letter_queue.
 * @version 1.0.0
 * @date 2026-08-09
 *
 * @author ZHENG Robert (robert @hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

ALTER TABLE dead_letter_queue DROP CONSTRAINT IF EXISTS dead_letter_queue_package_id_fkey;
