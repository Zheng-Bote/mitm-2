/**
 * SPDX-FileComment: Target Fragments Table
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 007_target_fragments.sql
 * @brief Migration script creating generic target_fragments table.
 */

CREATE TABLE IF NOT EXISTS target_fragments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    correlation_id UUID NOT NULL,
    topic VARCHAR(255) NOT NULL,
    payload_jsonb JSONB NOT NULL,
    delivery_status VARCHAR(50) DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_target_fragments_topic ON target_fragments(topic);
CREATE INDEX IF NOT EXISTS idx_target_fragments_status ON target_fragments(delivery_status);
