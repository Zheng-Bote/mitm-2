/**
 * SPDX-FileComment: WebAuthn Credentials and Department Migration
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: Antigravity
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 004_webauthn_and_department.sql
 * @brief Migration script adding department to admin_users and creating webauthn tables.
 */

-- 1. Add department to admin_users table
ALTER TABLE admin_users 
ADD COLUMN IF NOT EXISTS department VARCHAR(100);

-- 2. Create webauthn_credentials table
CREATE TABLE IF NOT EXISTS webauthn_credentials (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         INT NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    credential_id   TEXT NOT NULL UNIQUE,
    passkey_json    JSONB NOT NULL,
    aaguid          TEXT,
    sign_count      BIGINT DEFAULT 0,
    attachment_type VARCHAR(50) DEFAULT 'cross-platform',
    yubikey_serial  VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_used_at    TIMESTAMPTZ
);

COMMENT ON TABLE webauthn_credentials IS 'Stores WebAuthn passkeys and hardware attestation details for users.';
CREATE INDEX IF NOT EXISTS idx_webauthn_credentials_user_id ON webauthn_credentials(user_id);

-- 3. Create webauthn_states table for tracking challenges between start and finish
CREATE TABLE IF NOT EXISTS webauthn_states (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_type  VARCHAR(20) NOT NULL, -- 'register' or 'login'
    state_data      JSONB NOT NULL,
    user_id         INT REFERENCES admin_users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL
);

COMMENT ON TABLE webauthn_states IS 'Temporary storage for WebAuthn ceremony states (challenges).';
CREATE INDEX IF NOT EXISTS idx_webauthn_states_expires_at ON webauthn_states(expires_at);

-- 4. Ensure mitm_user has full privileges on newly created tables
GRANT ALL PRIVILEGES ON TABLE webauthn_credentials, webauthn_states TO mitm_user;
