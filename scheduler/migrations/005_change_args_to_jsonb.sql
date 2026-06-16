/**
 * SPDX-FileComment: Migrate scheduled_programs.args to JSONB
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 005_change_args_to_jsonb.sql
 * @brief Migration script changing scheduled_programs.args column to JSONB.
 * @version 1.0.0
 * @date 2026-06-05
 *
 * @author ZHENG Robert (robert@hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

ALTER TABLE scheduled_programs DROP COLUMN IF EXISTS args;
ALTER TABLE scheduled_programs ADD COLUMN args JSONB DEFAULT '{}'::jsonb;
