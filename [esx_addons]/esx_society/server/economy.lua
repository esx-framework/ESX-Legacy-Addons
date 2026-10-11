-- SPDX-License-Identifier: GPL-3.0-only
SocietyEconomy = { ready = false }

MySQL.ready(function()
    local ok, err = pcall(function()
        ESXCatalog.awaitReady()

        for _, name in ipairs({ 'users', 'society_moneywash', 'addon_account_data' }) do
            local engine = MySQL.scalar.await(
                [[SELECT ENGINE FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]],
                { name }
            )

            assert(engine and engine:upper() == 'INNODB', name .. ' must use InnoDB')
        end

        MySQL.query.await([[CREATE TABLE IF NOT EXISTS society_moneywash_operations (
            operation_id VARCHAR(100) NOT NULL PRIMARY KEY,
            identifier VARCHAR(60) NOT NULL, society VARCHAR(60) NOT NULL,
            amount INT NOT NULL, state VARCHAR(16) NOT NULL DEFAULT 'queued',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            KEY idx_moneywash_pending (state, operation_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

        local engine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'society_moneywash_operations']])

        assert(engine and engine:upper() == 'INNODB', 'society_moneywash_operations must use InnoDB')

        assert(
            MySQL.transaction.await({
                [[INSERT INTO society_moneywash_operations (operation_id, identifier, society, amount)
                SELECT CONCAT('legacy:', id), identifier, society, amount FROM society_moneywash
                WHERE NOT EXISTS (SELECT 1 FROM society_moneywash_operations p WHERE p.operation_id = CONCAT('legacy:', society_moneywash.id))]],
                [[DELETE w FROM society_moneywash w JOIN society_moneywash_operations p ON p.operation_id = CONCAT('legacy:', w.id)]],
            }),
            'Could not migrate pending moneywash entries'
        )
    end)

    SocietyEconomy.ready = ok

    if not ok then
        print('[esx_society] Moneywash disabled: ' .. tostring(err))
    end
end)

local function lookup(token)
    while true do
        local ok, result = pcall(MySQL.single.await, 'SELECT state, amount FROM society_moneywash_operations WHERE operation_id = ?', { token })

        if ok then
            return result
        end

        print('[esx_society] Waiting to reconcile moneywash operation ' .. token)
        Wait(5000)
    end
end

function SocietyEconomy.queue(player, society, amount)
    if not SocietyEconomy.ready then
        return false
    end

    return exports.es_extended:WithPlayerPersistence(player.getIdentifier(), function(current)
        if not current or current.source ~= player.source then
            return false
        end

        local raw = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = ?', { player.getIdentifier() })

        if not raw then
            return false
        end

        local accounts = current.getAccounts(true)

        if not accounts.black_money or accounts.black_money < amount then
            return false
        end

        accounts.black_money = accounts.black_money - amount

        local encoded = json.encode(accounts)
        local token = ('wash:%s:%s:%s'):format(os.time(), GetGameTimer(), math.random(1, 2147483647))

        if not current.removeAccountMoney('black_money', amount, 'Washing') then
            return false
        end

        pcall(MySQL.transaction.await, {
            {
                query = 'SELECT identifier FROM users WHERE identifier = ? FOR UPDATE',
                values = { player.getIdentifier() },
            },
            {
                query = [[INSERT INTO society_moneywash_operations (operation_id, identifier, society, amount)
                SELECT ?, identifier, ?, ? FROM users WHERE identifier = ? AND accounts = ?]],
                values = { token, society, amount, player.getIdentifier(), raw },
            },
            {
                query = [[UPDATE users u JOIN society_moneywash_operations p ON p.identifier = u.identifier
                SET u.accounts = ? WHERE p.operation_id = ?]],
                values = { encoded, token },
            },
        })

        if not lookup(token) then
            current.addAccountMoney('black_money', amount, 'Moneywash Refund')
            return false
        end

        return true
    end, true)
end

local running = false

function SocietyEconomy.payPending()
    if not SocietyEconomy.ready or running then
        return
    end

    running = true

    local ok, err = pcall(function()
        local cursor = ''

        while true do
            local entries = MySQL.query.await(
                [[SELECT operation_id, identifier, society, amount FROM society_moneywash_operations
                WHERE state = 'queued' AND operation_id > ? ORDER BY operation_id LIMIT 50]],
                { cursor }
            )

            if #entries == 0 then
                break
            end

            for _, entry in ipairs(entries) do
                cursor = entry.operation_id

                local society = GetSociety(entry.society)
                local account

                if society then
                    TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(value)
                        account = value
                    end)
                end

                if account and account.withPersistence then
                    account.withPersistence(function(balance)
                        local pending = lookup(entry.operation_id)

                        if not pending or pending.state ~= 'queued' or entry.amount < 1 or balance + entry.amount > 2147483647 then
                            return false
                        end

                        pcall(MySQL.transaction.await, {
                            {
                                query = 'SELECT operation_id FROM society_moneywash_operations WHERE operation_id = ? FOR UPDATE',
                                values = { entry.operation_id },
                            },
                            {
                                query = [[UPDATE addon_account_data a JOIN society_moneywash_operations p ON p.operation_id = ?
                                SET a.money = ? WHERE a.account_name = ? AND a.owner IS NULL AND p.state = 'queued']],
                                values = {
                                    entry.operation_id,
                                    balance + entry.amount,
                                    society.account,
                                },
                            },
                            {
                                query = [[UPDATE society_moneywash_operations p SET state = 'paid' WHERE operation_id = ? AND state = 'queued'
                                AND EXISTS (SELECT 1 FROM addon_account_data a WHERE a.account_name = ? AND a.owner IS NULL)]],
                                values = { entry.operation_id, society.account },
                            },
                        })

                        local paid = lookup(entry.operation_id)

                        return paid and paid.state == 'paid', entry.amount
                    end)
                else
                    print('[esx_society] Moneywash remains queued: ' .. entry.operation_id)
                end

                Wait(0)
            end
        end
    end)

    running = false

    if not ok then
        print('[esx_society] Moneywash run failed: ' .. tostring(err))
    end
end
