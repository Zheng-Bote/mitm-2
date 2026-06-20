-- 006_rbac.sql

-- Table for roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Default roles
INSERT INTO roles (name, description) VALUES
('ADMIN', 'Full access to all system features'),
('VIEWER', 'Read-only access to monitoring and logs'),
('UPLOADER', 'Access to manual file upload mechanisms (CSV/XLSX)')
ON CONFLICT (name) DO NOTHING;

-- Table for user roles (encrypted assignment)
-- Zuordnung von Rollen zu Usern soll manipulationssicher in der Datenbank verschlüsselt werden
CREATE TABLE IF NOT EXISTS user_roles_encrypted (
    user_id INT PRIMARY KEY REFERENCES admin_users(id) ON DELETE CASCADE,
    wrapped_dek BYTEA NOT NULL,
    nonce BYTEA NOT NULL,
    encrypted_roles BYTEA NOT NULL, -- Encrypted JSON array of role IDs
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
