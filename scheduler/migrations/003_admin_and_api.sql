-- 003_admin_and_api.sql

-- Table for administrative users
CREATE TABLE IF NOT EXISTS admin_users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL, -- Scrypt or Argon2 hash
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Note: We'll need a way to bootstrap an admin user.
-- For now, we'll use a simple "HELO" token in the config for demonstration,
-- but the table is ready for a full RBAC system.

-- Table for audit of administrative actions
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    action TEXT NOT NULL,
    details JSONB,
    ts TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
