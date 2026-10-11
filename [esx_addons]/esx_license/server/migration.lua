-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function MigrateLicenseSchema()
    local duplicates = MySQL.scalar.await([[
        SELECT EXISTS (SELECT 1 FROM user_licenses
            GROUP BY owner, type HAVING COUNT(*) > 1)
    ]])
    assert(
        tonumber(duplicates) == 0,
        'Duplicate user_licenses: reconcile owner/type duplicates and restart esx_license; no rows were removed.'
    )

    local unique = MySQL.scalar.await([[SELECT COUNT(*) FROM (
        SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'user_licenses' AND NON_UNIQUE = 0 GROUP BY INDEX_NAME
        HAVING COUNT(*) = 2 AND SUM(SUB_PART IS NOT NULL) = 0
        AND GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) IN ('owner,type', 'type,owner')
    ) AS unique_license_keys]])
    assert(tonumber(unique), 'Could not inspect user_licenses indexes.')
    if tonumber(unique) == 0 then
        MySQL.query.await(
            'ALTER TABLE user_licenses ADD UNIQUE KEY uq_user_licenses_owner_type (owner, type)'
        )
    end
end
