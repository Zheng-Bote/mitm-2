/**
 * SPDX-FileComment: MitM Aggregator Adapter Tokens
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: Antigravity
 * SPDX-FileCopyrightText: 2026 Antigravity
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 007_adapter_tokens.sql
 * @brief Migration script creating adapter_tokens table.
 *
 * @LICENSE Apache-2.0
 */

CREATE TABLE IF NOT EXISTS adapter_tokens (
    connection_hash VARCHAR(64) PRIMARY KEY, -- e.g. SHA-256 of endpoint + login
    access_token    TEXT NOT NULL,
    access_expiry   TIMESTAMPTZ,
    refresh_token   TEXT,
    refresh_expiry  TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE adapter_tokens IS 'Stores central authentication tokens (OAuth2) across multiple topics for the same adapter endpoint.';
