GarageReady = false

local TABLE <const> = "owned_vehicles"

---@param column string
---@return boolean
local function hasColumn(column)
    local count = MySQL.scalar.await(
        "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?",
        { TABLE, column })

    return (count or 0) > 0
end

---@param column string
---@param definition string
---@return boolean
local function ensureColumn(column, definition)
    if hasColumn(column) then
        return false
    end

    MySQL.query.await(("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(TABLE, column, definition))

    return true
end

---@type string[][]
local SCHEMA <const> = {
    { "parking", "VARCHAR(60) NULL DEFAULT NULL" },
    { "pound", "VARCHAR(60) NULL DEFAULT NULL" },
    { "custom_name", "VARCHAR(50) NULL DEFAULT NULL" },
    { "is_favorite", "TINYINT(1) NOT NULL DEFAULT 0" },
    { "last_used", "INT NULL DEFAULT NULL" },
    { "mileage", "INT NOT NULL DEFAULT 0" },
}

CreateThread(function()

    local added, legacy = 0, 0

    local ok, err = pcall(function()
        for i = 1, #SCHEMA do
            if ensureColumn(SCHEMA[i][1], SCHEMA[i][2]) then
                added = added + 1
            end
        end

        legacy = MySQL.scalar.await(("SELECT COUNT(*) FROM `%s` WHERE `stored` = 2"):format(TABLE)) or 0

        if legacy > 0 then
            local defaultLot = Config.Impounds and Config.Impounds[1] and Config.Impounds[1].id
            if defaultLot then
                MySQL.update.await(("UPDATE `%s` SET `stored` = 1, `parking` = NULL, `pound` = ? WHERE `stored` = 2"):format(TABLE),
                    { defaultLot })
            else
                MySQL.update.await(("UPDATE `%s` SET `stored` = 1, `parking` = NULL WHERE `stored` = 2"):format(TABLE))
            end
        end
    end)

    if not ok then
        print(("[esx_garage] db migration FAILED, garages will not serve vehicles: %s"):format(tostring(err)))
        return
    end

    GarageReady = true

    if added > 0 or legacy > 0 then
        print(("[esx_garage] db migration applied: %d column(s) added, %d legacy impound row(s) converted"):format(added, legacy))
    end
end)
