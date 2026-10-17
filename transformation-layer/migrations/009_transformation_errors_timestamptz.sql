/**
 * SPDX-FileComment: Transformation Layer Database Migrations
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 009_transformation_errors_timestamptz.sql
 * @brief Migration script changing transformation_errors.created_at to TIMESTAMPTZ.
 * @version 1.0.0
 * @date 2026-10-17
 *
 * @author ZHENG Robert (robert@hase-zheng.net)
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

-- Existing values are UTC wall-clock times: the transformation job writes via sqlx,
-- which sets the session TimeZone to UTC, so DEFAULT NOW() stored UTC.
-- Idempotent: only a 'timestamp without time zone' column is converted.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'transformation_errors'
          AND column_name = 'created_at'
          AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE transformation_errors
            ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC';
    END IF;
END $$;

ALTER TABLE transformation_errors ALTER COLUMN created_at SET DEFAULT NOW();
