/**
 * SPDX-FileComment: Admin Users E-Mail Migration
 * SPDX-FileType: SOURCE
 * SPDX-FileContributor: ZHENG Robert
 * SPDX-FileCopyrightText: 2026 ZHENG Robert
 * SPDX-License-Identifier: Apache-2.0
 *
 * @file 006_admin_users_email.sql
 * @brief Migration script adding the e-mail address (synchronized from OIDC logins) to admin_users.
 * @version 1.0.0
 * @date 2026-11-02
 *
 * @author ZHENG Robert
 * @copyright Copyright (c) 2026 ZHENG Robert
 * @license Apache-2.0
 */

ALTER TABLE admin_users
ADD COLUMN IF NOT EXISTS email TEXT;

COMMENT ON COLUMN admin_users.email IS 'E-mail address, synchronized from the OIDC email claim on login.';
