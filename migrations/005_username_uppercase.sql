/**
 * SPDX-FileComment: Canonical Uppercase Username Migration
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 005_username_uppercase.sql
 * @brief Migration script converting usernames to the canonical uppercase form and enforcing it.
 * @version 1.0.0
 * @date 2026-11-02
 *
 * @author ZHENG Robert
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

BEGIN;

-- Abort without changes if usernames collide after canonicalization or do not match the format.
-- Such rows must be resolved manually (rename or delete) before re-running this migration.
DO $$
DECLARE
    offenders TEXT;
BEGIN
    SELECT string_agg(names, '; ') INTO offenders FROM (
        SELECT string_agg(username, ', ') AS names
        FROM admin_users
        GROUP BY upper(btrim(username))
        HAVING count(*) > 1
    ) collisions;
    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION 'Usernames collide after uppercasing: %', offenders;
    END IF;

    SELECT string_agg(username, ', ') INTO offenders
    FROM admin_users
    WHERE upper(btrim(username)) !~ '^[A-Z0-9._-]{1,64}$';
    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION 'Usernames do not match ^[A-Z0-9._-]{1,64}$: %', offenders;
    END IF;
END $$;

UPDATE admin_users SET username = upper(btrim(username)) WHERE username <> upper(btrim(username));
UPDATE user_sessions SET os_user = upper(btrim(os_user)) WHERE os_user <> upper(btrim(os_user));

-- Pending WebAuthn ceremonies carry the old spelling; they expire within minutes anyway.
DELETE FROM webauthn_states;

ALTER TABLE admin_users DROP CONSTRAINT IF EXISTS admin_users_username_canonical;
ALTER TABLE admin_users ADD CONSTRAINT admin_users_username_canonical
    CHECK (username ~ '^[A-Z0-9._-]{1,64}$');

COMMIT;
