-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function MigrateBillingSchema()
    for _, name in ipairs({ 'billing', 'users' }) do
        local engine = MySQL.scalar.await(
            [[SELECT ENGINE FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]],
            { name }
        )
        assert(
            engine and engine:upper() == 'INNODB',
            name .. ' must exist and use InnoDB; automatic engine conversion is disabled.'
        )
    end
    local accountEngine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'addon_account_data']])
    assert(
        not accountEngine or accountEngine:upper() == 'INNODB',
        'addon_account_data must use InnoDB before enabling payments.'
    )

    local exists = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'billing_payments']])
    assert(tonumber(exists), 'Could not inspect billing_payments.')
    if tonumber(exists) == 0 then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS billing_payments (
                bill_id INT NOT NULL,
                operation_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
                identifier VARCHAR(60) NOT NULL,
                sender VARCHAR(60) NOT NULL,
                target_type VARCHAR(10) NOT NULL,
                target VARCHAR(100) NOT NULL,
                label VARCHAR(255) NOT NULL,
                amount INT NOT NULL,
                payment_account VARCHAR(20) NOT NULL,
                state ENUM('claimed', 'applied') NOT NULL DEFAULT 'claimed',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                applied_at TIMESTAMP NULL DEFAULT NULL,
                PRIMARY KEY (bill_id),
                UNIQUE KEY uq_billing_payment_operation (operation_id),
                KEY idx_billing_payment_state_created (state, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])
    end
    local journalEngine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'billing_payments']])
    assert(
        journalEngine and journalEngine:upper() == 'INNODB',
        'billing_payments must use InnoDB; review the existing table manually.'
    )
    MySQL.query.await(
        [[SELECT bill_id, operation_id, identifier, sender, target_type, target, label,
        amount, payment_account, state, created_at, applied_at FROM billing_payments LIMIT 0]]
    )
    local journalKeys = MySQL.scalar.await([[SELECT COUNT(DISTINCT key_columns) FROM (
        SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS key_columns
        FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'billing_payments' AND NON_UNIQUE = 0 GROUP BY INDEX_NAME
        HAVING COUNT(*) = 1 AND SUM(SUB_PART IS NOT NULL) = 0
    ) AS journal_keys WHERE key_columns IN ('bill_id', 'operation_id')]])
    assert(
        tonumber(journalKeys) == 2,
        'billing_payments requires unique bill_id and operation_id keys; review the existing table manually.'
    )

    local indexed = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'billing'
        AND COLUMN_NAME = 'identifier' AND SEQ_IN_INDEX = 1 AND SUB_PART IS NULL]])
    assert(tonumber(indexed), 'Could not inspect billing indexes.')
    if tonumber(indexed) == 0 then
        MySQL.query.await('ALTER TABLE billing ADD KEY idx_billing_identifier (identifier)')
    end
end
