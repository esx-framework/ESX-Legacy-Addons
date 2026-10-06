-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Superseded by sql/security_hardening_2026_10_02.sql.
-- Inspect duplicates and query plans with auditoria-2026-10-02/comprobaciones-db.sql.
-- The replacement checks existing indexes and refuses duplicate financial rows.
-- Optional performance indexes require EXPLAIN and representative measurements.
-- InnoDB secondary indexes already contain the primary key; do not blindly add
-- (identifier,id) on billing or (owner,plate) on owned_vehicles.
SELECT 'Use sql/security_hardening_2026_10_02.sql after duplicate inspection and backup' AS migration;
