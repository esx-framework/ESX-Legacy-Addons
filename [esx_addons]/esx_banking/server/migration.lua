-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function MigrateBankingSchema()
    local usersEngine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users']])
    assert(
        usersEngine and usersEngine:upper() == 'INNODB',
        'users must exist and use InnoDB before enabling banking.'
    )
    local exists = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'banking']])
    assert(tonumber(exists), 'Could not inspect banking.')
    if tonumber(exists) == 0 then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS banking (
                identifier VARCHAR(46) DEFAULT NULL,
                type VARCHAR(50) DEFAULT NULL,
                amount INT DEFAULT NULL,
                time BIGINT DEFAULT NULL,
                ID INT NOT NULL AUTO_INCREMENT,
                balance INT DEFAULT 0,
                label VARCHAR(255) DEFAULT NULL,
                PRIMARY KEY (ID),
                KEY idx_banking_identifier_time (identifier, time),
                KEY idx_banking_time (time)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
    end
    local engine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'banking']])
    assert(
        engine and engine:upper() == 'INNODB',
        'banking must use InnoDB; automatic engine conversion is disabled.'
    )
    MySQL.query.await(
        'SELECT identifier, type, amount, time, ID, balance, label FROM banking LIMIT 0'
    )

    local pin = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'pincode']])
    assert(tonumber(pin), 'Could not inspect users.pincode.')
    if tonumber(pin) == 0 then
        MySQL.query.await('ALTER TABLE users ADD COLUMN pincode INT NULL')
    end

    local indexes = MySQL.query.await(
        [[SELECT GROUP_CONCAT(COALESCE(COLUMN_NAME, '<expression>') ORDER BY SEQ_IN_INDEX) AS columns_list
        FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'banking' GROUP BY INDEX_NAME HAVING SUM(SUB_PART IS NOT NULL) = 0]]
    )
    assert(type(indexes) == 'table', 'Could not inspect banking indexes.')
    local history = false
    local time = false
    for _, index in ipairs(indexes) do
        local columns = tostring(index.columns_list) .. ','
        history = history or columns:sub(1, 16) == 'identifier,time,'
        time = time or columns:sub(1, 5) == 'time,'
    end
    if not history then
        MySQL.query.await('CREATE INDEX idx_banking_identifier_time ON banking (identifier, time)')
    end
    if not time then
        MySQL.query.await('CREATE INDEX idx_banking_time ON banking (time)')
    end
end
