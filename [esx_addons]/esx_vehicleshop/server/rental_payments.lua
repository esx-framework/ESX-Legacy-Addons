-- SPDX-License-Identifier: GPL-3.0-only
-- Daily rental charges use a durable receipt and commit both balances together.

local ready, running = false, false

MySQL.ready(function()
    local ok, err = pcall(function()
        for _, name in ipairs({ 'users', 'rented_vehicles', 'addon_account_data' }) do
            local engine = MySQL.scalar.await(
                [[SELECT ENGINE FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]],
                { name }
            )

            assert(engine and engine:upper() == 'INNODB', name .. ' must use InnoDB')
        end

        MySQL.query.await([[CREATE TABLE IF NOT EXISTS vehicle_rental_payments (
            plate VARCHAR(12) NOT NULL, billing_date DATE NOT NULL,
            owner VARCHAR(60) NOT NULL, amount INT NOT NULL,
            operation_id VARCHAR(100) NOT NULL, state VARCHAR(16) NOT NULL,
            PRIMARY KEY (plate, billing_date), UNIQUE KEY (operation_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

        local engine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vehicle_rental_payments']])

        assert(engine and engine:upper() == 'INNODB', 'vehicle_rental_payments must use InnoDB')
    end)

    ready = ok

    if not ok then
        print('[esx_vehicleshop] Rental payments disabled: ' .. tostring(err))
    end
end)

local function receipt(plate, day, token)
    while true do
        local ok, row =
            pcall(MySQL.single.await, 'SELECT operation_id, amount, state FROM vehicle_rental_payments WHERE plate = ? AND billing_date = ?', { plate, day })

        if ok then
            return row and row.operation_id == token and row or nil
        end

        print('[esx_vehicleshop] Waiting to reconcile rental payment ' .. token)
        Wait(5000)
    end
end

local function charge(rental, day, society)
    return society.withPersistence(function(societyBalance)
        local delta = 0

        local success = exports.es_extended:WithPlayerPersistence(rental.owner, function(player)
            if MySQL.scalar.await('SELECT 1 FROM vehicle_rental_payments WHERE plate = ? AND billing_date = ?', { rental.plate, day }) then
                return false
            end

            local raw = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = ?', { rental.owner })
            local ok, accounts = pcall(json.decode, raw or '')
            local price = tonumber(rental.rent_price)

            if not ok or type(accounts) ~= 'table' or not price or price < 1 or price % 1 ~= 0 or price > 2147483647 then
                print('[esx_vehicleshop] Invalid rental/user data: ' .. rental.plate)
                return false
            end

            if player then
                accounts = player.getAccounts(true)
            end

            local bank = accounts.bank

            if type(bank) ~= 'number' or bank ~= bank or bank < 0 or bank > 9007199254740991 then
                return false
            end

            local amount = bank >= price and price or 0

            if societyBalance + amount > 2147483647 then
                return false
            end

            local state = amount > 0 and 'paid' or 'evicted'
            local token = ('%s:%s:%s:%s'):format(rental.plate, day, GetGameTimer(), math.random(1, 2147483647))

            accounts.bank = bank - amount

            local encoded = json.encode(accounts)

            if player and amount > 0 and not player.removeAccountMoney('bank', amount, 'Vehicle Rental') then
                return false
            end

            local committed, err = pcall(MySQL.transaction.await, {
                {
                    query = 'SELECT identifier FROM users WHERE identifier = ? FOR UPDATE',
                    values = { rental.owner },
                },
                {
                    query = "SELECT id FROM addon_account_data WHERE account_name = 'society_cardealer' AND owner IS NULL FOR UPDATE",
                    values = {},
                },
                {
                    query = [[INSERT INTO vehicle_rental_payments (plate, billing_date, owner, amount, operation_id, state)
                    SELECT r.plate, ?, r.owner, ?, ?, ? FROM rented_vehicles r
                    JOIN users u ON u.identifier = r.owner
                    JOIN addon_account_data a ON a.account_name = 'society_cardealer' AND a.owner IS NULL
                    WHERE r.plate = ? AND r.owner = ? AND r.rent_price = ? AND u.accounts = ?]],
                    values = { day, amount, token, state, rental.plate, rental.owner, price, raw },
                },
                {
                    query = [[UPDATE users u JOIN vehicle_rental_payments p ON p.owner = u.identifier
                    SET u.accounts = ? WHERE p.operation_id = ?]],
                    values = { encoded, token },
                },
                {
                    query = [[UPDATE addon_account_data a JOIN vehicle_rental_payments p ON p.operation_id = ?
                    SET a.money = ? WHERE a.account_name = 'society_cardealer' AND a.owner IS NULL]],
                    values = { token, societyBalance + amount },
                },
                {
                    query = [[DELETE r FROM rented_vehicles r JOIN vehicle_rental_payments p ON p.plate = r.plate
                    AND p.owner = r.owner WHERE p.operation_id = ? AND p.state = 'evicted']],
                    values = { token },
                },
            })

            if not committed or err ~= true then
                print('[esx_vehicleshop] Rental transaction unconfirmed: ' .. tostring(err))
            end

            local paid = receipt(rental.plate, day, token)

            if not paid then
                if player and amount > 0 then
                    player.addAccountMoney('bank', amount, 'Vehicle Rental Refund')
                end

                return false
            end

            delta = paid.amount

            if player then
                pcall(
                    player.showNotification,
                    TranslateCap(paid.state == 'paid' and 'paid_rental' or 'paid_rental_evicted', ESX.Math.GroupDigits(price), rental.plate)
                )
            end

            return true
        end, true)

        return success, delta
    end)
end

function PayRent()
    if not ready or running then
        return
    end

    running = true

    local started, day = GetGameTimer(), os.date('%Y-%m-%d')

    local ok, err = pcall(function()
        local society

        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_cardealer', function(account)
            society = account
        end)

        assert(society and society.withPersistence, 'Transactional society account unavailable')

        local cursor = ''

        while true do
            local rentals = MySQL.query.await(
                [[SELECT owner, rent_price, plate FROM rented_vehicles
                WHERE plate > ? ORDER BY plate LIMIT 50]],
                { cursor }
            )

            if #rentals == 0 then
                break
            end

            for _, rental in ipairs(rentals) do
                charge(rental, day, society)
                cursor = rental.plate
                Wait(0)
            end
        end
    end)

    running = false

    if not ok then
        print('[esx_vehicleshop] Rental run failed: ' .. tostring(err))
    end

    print(('[esx_vehicleshop] Rental payments finished in %s ms'):format(GetGameTimer() - started))
end

TriggerEvent('cron:runAt', 22, 0, function()
    PayRent()
end)
