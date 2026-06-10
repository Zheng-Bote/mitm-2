/**
 * SPDX-FileComment: Add topic to packages
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 */

ALTER TABLE packages ADD COLUMN IF NOT EXISTS topic VARCHAR(255) DEFAULT 'default';
CREATE INDEX IF NOT EXISTS idx_packages_topic_status ON packages (topic, status);
