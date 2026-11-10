/**
 * SPDX-FileComment: Maintenance Monitor State Migration
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 007_monitor_state.sql
 * @brief Migration script adding the feature tables of mitm_maintenance_monitor (source cursors and alert suppression state).
 * @version 1.0.0
 * @date 2026-11-10
 *
 * @author ZHENG Robert
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

CREATE TABLE IF NOT EXISTS monitor_state (
    source      VARCHAR(50) PRIMARY KEY,           -- 'program_runs', 'system_logs', 'dead_letter_queue'
    last_ts     TIMESTAMPTZ,                       -- timestamp part of the cursor (program_runs, dead_letter_queue)
    last_id     TEXT NOT NULL DEFAULT '',          -- id part of the cursor
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE monitor_state IS 'mitm_maintenance_monitor: last processed position per monitored source.';

CREATE TABLE IF NOT EXISTS monitor_alerts (
    fingerprint      VARCHAR(64) PRIMARY KEY,      -- SHA-256 of category, subject and normalized error
    category         VARCHAR(20) NOT NULL,         -- 'job', 'system', 'dlq'
    job_name         TEXT,                         -- set for job alerts (recovery detection)
    summary          TEXT NOT NULL,                -- truncated description, no payloads
    first_seen       TIMESTAMPTZ NOT NULL,
    last_seen        TIMESTAMPTZ NOT NULL,
    last_mailed_at   TIMESTAMPTZ,
    suppressed_count INT NOT NULL DEFAULT 0,       -- occurrences since last_mailed_at without a mail
    is_open          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_monitor_alerts_open_job ON monitor_alerts (job_name) WHERE is_open;

COMMENT ON TABLE monitor_alerts IS 'mitm_maintenance_monitor: suppression and recovery state per alert fingerprint.';

GRANT ALL PRIVILEGES ON TABLE monitor_state, monitor_alerts TO mitm_user;
