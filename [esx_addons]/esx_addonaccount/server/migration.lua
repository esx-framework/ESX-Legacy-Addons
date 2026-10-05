-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function MigrateAddonAccountSchema()
    local engine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'addon_account_data']])
    assert(
        engine and engine:upper() == 'INNODB',
        'addon_account_data must exist and use InnoDB; automatic engine conversion is disabled.'
    )

    local invalid = MySQL.scalar.await([[SELECT EXISTS (SELECT 1 FROM addon_account_data
        WHERE account_name IS NULL OR owner = '')]])
    assert(
        tonumber(invalid) == 0,
        'Invalid account_name/empty owner: reconcile addon_account_data and restart esx_addonaccount; balances were not changed.'
    )
    local duplicates = MySQL.scalar.await([[SELECT EXISTS (SELECT 1 FROM addon_account_data
        GROUP BY account_name, COALESCE(owner, '') HAVING COUNT(*) > 1)]])
    assert(
        tonumber(duplicates) == 0,
        'Duplicate addon accounts: reconcile balances and restart esx_addonaccount; no rows were merged or removed.'
    )

    local columns =
        MySQL.query.await([[SELECT DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, EXTRA, GENERATION_EXPRESSION
        FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'addon_account_data' AND COLUMN_NAME = 'owner_key']])
    assert(type(columns) == 'table', 'Could not inspect addon_account_data.owner_key.')
    if #columns == 0 then
        MySQL.query.await([[ALTER TABLE addon_account_data ADD COLUMN owner_key VARCHAR(60)
            GENERATED ALWAYS AS (COALESCE(owner, '')) STORED]])
    else
        local column = columns[1]
        local expression = tostring(column.GENERATION_EXPRESSION or ''):lower():gsub('[%s`()]', '')
        assert(
            column.DATA_TYPE == 'varchar'
                and (tonumber(column.CHARACTER_MAXIMUM_LENGTH) or 0) >= 60
                and tostring(column.EXTRA):upper():find('STORED', 1, true)
                and (expression == "coalesceowner,''" or expression == "ifnullowner,''"),
            'Existing owner_key is incompatible: expected a stored generated COALESCE(owner, empty string) column; review it manually.'
        )
    end

    local unique = MySQL.scalar.await([[SELECT COUNT(*) FROM (
        SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'addon_account_data' AND NON_UNIQUE = 0 GROUP BY INDEX_NAME
        HAVING COUNT(*) = 2 AND SUM(SUB_PART IS NOT NULL) = 0
        AND GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) IN ('account_name,owner_key', 'owner_key,account_name')
    ) AS unique_account_keys]])
    assert(tonumber(unique), 'Could not inspect addon_account_data indexes.')
    if tonumber(unique) == 0 then
        MySQL.query.await(
            'ALTER TABLE addon_account_data ADD UNIQUE KEY uq_addon_account_owner_key (account_name, owner_key)'
        )
    end
end
