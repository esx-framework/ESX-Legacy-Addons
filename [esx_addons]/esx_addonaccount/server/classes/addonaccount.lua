-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function CreateAddonAccount(name, owner, money)
    local self = {
        name = name,
        owner = owner,
        money = money,
    }

    local revision = 0
    local persisted = 0
    local writing = false
    local waiters = {}

    local function valid(amount)
        return type(amount) == 'number'
            and amount == amount
            and amount >= 0
            and amount <= 2147483647
            and amount % 1 == 0
    end

    local pump

    pump = function()
        if writing or persisted == revision then
            return
        end

        writing = true

        local version = revision
        local snapshot = self.money
        local query
        local params

        if owner == nil then
            query =
                'UPDATE addon_account_data SET money = ? WHERE account_name = ? AND owner IS NULL'
            params = { snapshot, name }
        else
            query = 'UPDATE addon_account_data SET money = ? WHERE account_name = ? AND owner = ?'
            params = { snapshot, name, owner }
        end

        local finished = false
        local verifiedZero = false

        local function finish(rows)
            if finished then
                return
            end

            if rows == 0 and not verifiedZero then
                verifiedZero = true

                local lookup = owner == nil
                        and 'SELECT money FROM addon_account_data WHERE account_name = ? AND owner IS NULL'
                    or 'SELECT money FROM addon_account_data WHERE account_name = ? AND owner = ?'

                local values = owner == nil and { name } or { name, owner }

                local ok = pcall(MySQL.query, lookup, values, function(result)
                    finish(
                        type(result) == 'table'
                                and #result == 1
                                and result[1].money == snapshot
                                and 1
                            or nil
                    )
                end)

                if not ok then
                    finish(nil)
                end

                return
            end

            finished = true
            writing = false

            local success = type(rows) == 'number' and rows >= 0 and rows <= 1

            if success then
                persisted = version
            end

            local callbacks = {}

            for i = #waiters, 1, -1 do
                if not success or waiters[i].version <= version then
                    callbacks[#callbacks + 1] = waiters[i].cb
                    table.remove(waiters, i)
                end
            end

            for i = 1, #callbacks do
                local ok, err = pcall(callbacks[i], success)

                if not ok then
                    print(('[esx_addonaccount] save callback failed: %s'):format(err))
                end
            end

            if not success then
                print(('[esx_addonaccount] Unconfirmed save for %s; retrying'):format(name))
                SetTimeout(5000, pump)
            elseif persisted ~= revision then
                pump()
            end
        end

        local ok = pcall(MySQL.update, query, params, finish)

        if not ok then
            finish(nil)
        end
    end

    function self.save(cb)
        if cb then
            if persisted == revision and not writing then
                return cb(true)
            end

            waiters[#waiters + 1] = {
                version = revision,
                cb = cb,
            }
        end

        pump()
    end

    function self.isDirty()
        return writing or persisted ~= revision
    end

    local function change(amount, event, delta)
        if not valid(amount) or not valid(self.money + delta) then
            return false
        end

        if delta == 0 then
            return true
        end

        self.money = self.money + delta
        revision = revision + 1

        self.save()
        TriggerEvent(event, name, amount, owner)

        return true
    end

    function self.addMoney(amount)
        if not valid(amount) then
            return false
        end

        return change(amount, 'esx_addonaccount:addMoney', amount)
    end

    function self.removeMoney(amount)
        if not valid(amount) then
            return false
        end

        return change(amount, 'esx_addonaccount:removeMoney', -amount)
    end

    function self.setMoney(amount)
        if not valid(amount) then
            return false
        end

        return change(amount, 'esx_addonaccount:setMoney', amount - self.money)
    end

    return self
end
