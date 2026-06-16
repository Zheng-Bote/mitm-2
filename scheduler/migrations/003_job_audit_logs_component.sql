/**
 * SPDX-FileComment: Job Audit Logs Component
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 */

ALTER TABLE job_audit_logs ADD COLUMN IF NOT EXISTS component VARCHAR(255) DEFAULT 'Scheduler';
