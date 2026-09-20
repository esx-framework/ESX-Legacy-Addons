-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

GarageReady = false

local TABLE <const> = "owned_vehicles"
local MIGRATION_TABLE <const> = "esx_garage_migrations"
local MIGRATION_NAME <const> = "schema"
local INDEX_MIGRATION_NAME <const> = "performance_indexes"
local FILTER_INDEX_MIGRATION_NAME <const> = "filter_indexes"
local MILEAGE_PRECISION_MIGRATION_NAME <const> = "mileage_precision"
local POUND_NORMALIZATION_MIGRATION_NAME <const> = "pound_normalization"
local LEGACY_MIGRATION_VERSION <const> = "1"
local MIGRATION_VERSION <const> = "1.14.2"

---@param name string
---@return string?
local function appliedMigrationVersion(name)
    local ok, version = pcall(MySQL.scalar.await,
        ("SELECT `version` FROM `%s` WHERE `name` = ?"):format(MIGRATION_TABLE),
        { name })

    if not ok or version == nil then
        return nil
    end

    return tostring(version)
end

---@param version string?
---@return boolean
local function migrationApplied(version)
    return version == MIGRATION_VERSION or version == LEGACY_MIGRATION_VERSION
end

local function ensureMigrationTable()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `name` VARCHAR(64) NOT NULL,
            `version` VARCHAR(32) NOT NULL DEFAULT '0',
            `applied_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`name`)
        )
    ]]):format(MIGRATION_TABLE))

    local versionType = MySQL.scalar.await(
        "SELECT DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = 'version'",
        { MIGRATION_TABLE })

    if versionType ~= "varchar" then
        MySQL.query.await(("ALTER TABLE `%s` MODIFY COLUMN `version` VARCHAR(32) NOT NULL DEFAULT '0'"):format(MIGRATION_TABLE))
    end
end

---@param name string
local function markMigrationApplied(name)
    local now = os.time()

    MySQL.query.await(
        ("INSERT INTO `%s` (`name`, `version`, `applied_at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `version` = ?, `applied_at` = ?")
            :format(MIGRATION_TABLE),
        { name, MIGRATION_VERSION, now, MIGRATION_VERSION, now })
end

---@param column string
---@return boolean
local function hasColumn(column)
    local count = MySQL.scalar.await(
        "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?",
        { TABLE, column })

    return (count or 0) > 0
end

---@param index string
---@return boolean
local function hasIndex(index)
    local count = MySQL.scalar.await(
        "SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?",
        { TABLE, index })

    return (count or 0) > 0
end

---@param column string
---@return boolean
local function hasLeadingIndex(column)
    local count = MySQL.scalar.await(
        "SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? AND SEQ_IN_INDEX = 1",
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

---@return boolean
local function mileageColumnNeedsPrecision()
    local rows = MySQL.query.await(
        "SELECT DATA_TYPE AS data_type, NUMERIC_PRECISION AS numeric_precision, NUMERIC_SCALE AS numeric_scale, IS_NULLABLE AS is_nullable, COLUMN_DEFAULT AS column_default FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = 'mileage'",
        { TABLE })
    local column = rows and rows[1]

    if not column then
        return false
    end

    return tostring(column.data_type or ""):lower() ~= "decimal"
        or tonumber(column.numeric_precision) ~= 10
        or tonumber(column.numeric_scale) ~= 2
        or tostring(column.is_nullable or ""):upper() ~= "NO"
        or tonumber(column.column_default) ~= 0
end

---@param index string
---@param definition string
---@return boolean
local function ensureIndex(index, definition)
    if hasIndex(index) then
        return false
    end

    MySQL.query.await(("ALTER TABLE `%s` ADD INDEX `%s` %s"):format(TABLE, index, definition))

    return true
end

---@param index string
---@param column string
---@param definition string
---@return boolean
local function ensureLeadingIndex(index, column, definition)
    if hasLeadingIndex(column) then
        return false
    end

    MySQL.query.await(("ALTER TABLE `%s` ADD INDEX `%s` %s"):format(TABLE, index, definition))

    return true
end

---@type string[][]
local SCHEMA <const> = {
    { "parking", "VARCHAR(60) NULL DEFAULT NULL" },
    { "pound", "VARCHAR(60) NULL DEFAULT NULL" },
    { "custom_name", "VARCHAR(50) NULL DEFAULT NULL" },
    { "is_favorite", "TINYINT(1) NOT NULL DEFAULT 0" },
    { "last_used", "INT NULL DEFAULT NULL" },
    { "mileage", "DECIMAL(10,2) NOT NULL DEFAULT 0.00" },
}

---@type string[][]
local INDEXES <const> = {
    { "idx_owned_vehicles_owner_plate", "(`owner`, `plate`)" },
    { "idx_owned_vehicles_owner_custom_name", "(`owner`, `custom_name`)" },
    { "idx_owned_vehicles_owner_stored_pound_plate", "(`owner`, `stored`, `pound`, `plate`)" },
    { "idx_owned_vehicles_owner_pound_plate_stored", "(`owner`, `pound`, `plate`, `stored`)" },
    { "idx_owned_vehicles_plate_stored_pound", "(`plate`, `stored`, `pound`)" },
    { "idx_owned_vehicles_owner_favorite_plate", "(`owner`, `is_favorite`, `plate`)" },
}

---@type string[][]
local FILTER_INDEXES <const> = {
    { "idx_owned_vehicles_owner_stored_pound_plate", "(`owner`, `stored`, `pound`, `plate`)" },
    { "idx_owned_vehicles_owner_favorite_plate", "(`owner`, `is_favorite`, `plate`)" },
}

CreateThread(function()

    local added, indexed, legacy, adjusted = 0, 0, 0, 0

    local ok, err = pcall(function()
        local version = appliedMigrationVersion(MIGRATION_NAME)
        if migrationApplied(version) then
            if version ~= MIGRATION_VERSION then
                ensureMigrationTable()
                markMigrationApplied(MIGRATION_NAME)
            end
        else
            ensureMigrationTable()

            for i = 1, #SCHEMA do
                if ensureColumn(SCHEMA[i][1], SCHEMA[i][2]) then
                    added = added + 1
                end
            end

            for i = 1, #INDEXES do
                if ensureIndex(INDEXES[i][1], INDEXES[i][2]) then
                    indexed = indexed + 1
                end
            end

            if ensureLeadingIndex("idx_owned_vehicles_plate", "plate", "(`plate`)") then
                indexed = indexed + 1
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

            markMigrationApplied(MIGRATION_NAME)
        end

        if not migrationApplied(appliedMigrationVersion(INDEX_MIGRATION_NAME)) then
            ensureMigrationTable()

            for i = 1, #SCHEMA do
                if ensureColumn(SCHEMA[i][1], SCHEMA[i][2]) then
                    added = added + 1
                end
            end

            for i = 1, #INDEXES do
                if ensureIndex(INDEXES[i][1], INDEXES[i][2]) then
                    indexed = indexed + 1
                end
            end

            if ensureLeadingIndex("idx_owned_vehicles_plate", "plate", "(`plate`)") then
                indexed = indexed + 1
            end

            markMigrationApplied(INDEX_MIGRATION_NAME)
        end

        if not migrationApplied(appliedMigrationVersion(FILTER_INDEX_MIGRATION_NAME)) then
            ensureMigrationTable()

            for i = 1, #SCHEMA do
                if ensureColumn(SCHEMA[i][1], SCHEMA[i][2]) then
                    added = added + 1
                end
            end

            for i = 1, #FILTER_INDEXES do
                if ensureIndex(FILTER_INDEXES[i][1], FILTER_INDEXES[i][2]) then
                    indexed = indexed + 1
                end
            end

            markMigrationApplied(FILTER_INDEX_MIGRATION_NAME)
        end

        if not migrationApplied(appliedMigrationVersion(POUND_NORMALIZATION_MIGRATION_NAME)) then
            ensureMigrationTable()

            if ensureColumn("pound", "VARCHAR(60) NULL DEFAULT NULL") then
                added = added + 1
            end

            if ensureIndex("idx_owned_vehicles_plate_stored_pound", "(`plate`, `stored`, `pound`)") then
                indexed = indexed + 1
            end

            MySQL.update.await(("UPDATE `%s` SET `pound` = NULL WHERE `pound` = ''"):format(TABLE))
            markMigrationApplied(POUND_NORMALIZATION_MIGRATION_NAME)
        end

        if not migrationApplied(appliedMigrationVersion(MILEAGE_PRECISION_MIGRATION_NAME)) then
            ensureMigrationTable()

            if ensureColumn("mileage", "DECIMAL(10,2) NOT NULL DEFAULT 0.00") then
                added = added + 1
            elseif mileageColumnNeedsPrecision() then
                MySQL.update.await(("UPDATE `%s` SET `mileage` = 0 WHERE `mileage` IS NULL"):format(TABLE))
                MySQL.query.await(("ALTER TABLE `%s` MODIFY COLUMN `mileage` DECIMAL(10,2) NOT NULL DEFAULT 0.00"):format(TABLE))
                adjusted = adjusted + 1
            end

            markMigrationApplied(MILEAGE_PRECISION_MIGRATION_NAME)
        end
    end)

    if not ok then
        print(("[esx_garage] db migration FAILED, garages will not serve vehicles: %s"):format(tostring(err)))
        return
    end

    GarageReady = true

    if added > 0 or indexed > 0 or legacy > 0 or adjusted > 0 then
        print(("[esx_garage] db migration applied: %d column(s) added, %d column(s) adjusted, %d index(es) added, %d legacy impound row(s) converted"):format(added, adjusted, indexed, legacy))
    end
end)
