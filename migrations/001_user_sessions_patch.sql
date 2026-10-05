/**
 * SPDX-FileComment: User Sessions Migration
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 001_user_sessions_patch.sql
 * @brief Migration script creating user_sessions table for token-based auth.
 */

CREATE TABLE IF NOT EXISTS user_sessions (
    session_token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    os_user VARCHAR(255) NOT NULL,
    
    -- Absolute 24h TTL
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL, 
    
    -- 2h Idle Timeout
    last_active_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    client_ip VARCHAR(45)
);

COMMENT ON TABLE user_sessions IS 'Stores active user sessions, enforcing absolute TTL and idle timeouts.';

CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON user_sessions(expires_at, last_active_at);
