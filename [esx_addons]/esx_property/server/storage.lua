-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

PropertyStorage = {}

local initialized = false
local loaded = false
local persisted = {}
local busy = false
local batchRows <const> = 100
local batchBytes <const> = 262144
local migrationName <const> = 'properties_json_to_sql_v1'

local createProperties <const> = [[
    CREATE TABLE IF NOT EXISTS `esx_properties` (
        `id` INT UNSIGNED NOT NULL,
        `data` LONGTEXT NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]]

local createMigrations <const> = [[
    CREATE TABLE IF NOT EXISTS `esx_property_migrations` (
        `name` VARCHAR(64) NOT NULL,
        `completed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]]

local function verifyTable(name, primary)
    local engine = MySQL.scalar.await([[SELECT ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { name })

    assert(type(engine) == 'string' and engine:upper() == 'INNODB', name .. ' must use InnoDB; writes are disabled')

    local indexes = MySQL.query.await([[SELECT INDEX_NAME, COLUMN_NAME, SEQ_IN_INDEX, SUB_PART, NON_UNIQUE
        FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { name })

    assert(type(indexes) == 'table', 'Could not inspect indexes for ' .. name)

    local primaryCount = 0

    for _, index in ipairs(indexes) do
        if index.INDEX_NAME == 'PRIMARY' then
            primaryCount = primaryCount + 1
            assert(index.COLUMN_NAME == primary and tonumber(index.SEQ_IN_INDEX) == 1 and not index.SUB_PART,
                name .. ' has an incompatible primary key')
        else
            assert(tonumber(index.NON_UNIQUE) == 1, name .. ' has an unexpected unique index')
        end
    end

    assert(primaryCount == 1, name .. ' requires PRIMARY KEY (' .. primary .. ')')

    local columns = MySQL.query.await([[SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, CHARACTER_MAXIMUM_LENGTH
        FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { name })

    assert(type(columns) == 'table', 'Could not inspect columns for ' .. name)

    local byName = {}

    for _, column in ipairs(columns) do byName[column.COLUMN_NAME] = column end

    if primary == 'id' then
        assert(byName.id and byName.id.DATA_TYPE == 'int' and byName.id.IS_NULLABLE == 'NO'
            and type(byName.id.COLUMN_TYPE) == 'string' and byName.id.COLUMN_TYPE:lower():find('unsigned', 1, true),
            name .. '.id must be INT UNSIGNED NOT NULL')

        assert(byName.data and byName.data.DATA_TYPE == 'longtext' and byName.data.IS_NULLABLE == 'NO',
            name .. '.data must be LONGTEXT NOT NULL')
    else
        assert(byName.name and byName.name.DATA_TYPE == 'varchar' and byName.name.IS_NULLABLE == 'NO'
            and (tonumber(byName.name.CHARACTER_MAXIMUM_LENGTH) or 0) >= 64, name .. '.name must be VARCHAR(64) NOT NULL')
    end
end

local function normalizeProperties(properties)
    assert(type(properties) == 'table', 'Property data must be an array or numeric-keyed object')
    local result, count = {}, 0

    for key, property in pairs(properties) do
        local id = tonumber(key)
        
        assert(id and id >= 1 and id <= 4294967295 and id == math.floor(id), 'Invalid property ID')
        assert(not result[id], 'Duplicate property ID')
        assert(type(property) == 'table', ('Invalid data for property %d'):format(id))

        result[id] = property

        count = count + 1
    end

    for id = 1, count do
        assert(result[id], ('Missing property ID %d; refusing to renumber properties'):format(id))
    end

    return result, count
end

local function encodeProperty(property)
    local data = {}

    for key, value in pairs(property) do
        if key ~= 'plysinside' then
            data[key] = value
        end
    end

    return json.encode(data)
end

local function addUpserts(queries, changes, upsert)
    local ids = {}

    for id in pairs(changes) do ids[#ids + 1] = id end

    table.sort(ids)

    local marks, values, bytes = {}, {}, 0

    local function flush()
        if #marks == 0 then return end

        queries[#queries + 1] = {
            query = 'INSERT INTO `esx_properties` (`id`, `data`) VALUES ' .. table.concat(marks, ', ')
                .. (upsert and ' ON DUPLICATE KEY UPDATE `data` = VALUES(`data`)' or ''),
            values = values,
        }

        marks, values, bytes = {}, {}, 0
    end
    
    for _, id in ipairs(ids) do
        local encoded = changes[id]
        local size = #encoded * 2 + 32

        if #marks >= batchRows or (#marks > 0 and bytes + size > batchBytes) then flush() end

        marks[#marks + 1] = '(?, ?)'
        values[#values + 1], values[#values + 2] = id, encoded
        bytes = bytes + size
    end

    flush()
end

local function migrationComplete()
    return MySQL.scalar.await('SELECT `name` FROM `esx_property_migrations` WHERE `name` = ?', { migrationName }) == migrationName
end

local function initialize(prepare)
    if initialized then
        return
    end

    assert(MySQL.query.await(createProperties), 'Could not create esx_properties')
    assert(MySQL.query.await(createMigrations), 'Could not create esx_property_migrations')
    verifyTable('esx_properties', 'id')
    verifyTable('esx_property_migrations', 'name')

    if not migrationComplete() then
        local existing = MySQL.scalar.await('SELECT EXISTS(SELECT 1 FROM `esx_properties` LIMIT 1)')
        assert(tonumber(existing) == 0, 'SQL properties exist without a migration marker; refusing to overwrite them')

        local legacy = LoadResourceFile(GetCurrentResourceName(), 'properties.json')
        assert(type(legacy) == 'string' and legacy:find('%S'), 'properties.json is missing or empty; SQL migration was not completed')

        local ok, decoded = pcall(json.decode, legacy)
        assert(ok and type(decoded) == 'table', 'properties.json is invalid; SQL migration was not completed')

        local properties, count = normalizeProperties(decoded)
        if prepare then
            prepare(properties)
        end

        local queries, changes = {}, {}

        for id = 1, count do
            changes[id] = encodeProperty(properties[id])
        end
        addUpserts(queries, changes, false)

        queries[#queries + 1] = {
            query = 'INSERT INTO `esx_property_migrations` (`name`) VALUES (?)',
            values = { migrationName },
        }

        local committed = MySQL.transaction.await(queries)

        assert(committed == true or migrationComplete(), 'Property JSON migration transaction failed; the original file is unchanged')
        print(('[esx_property] Imported %d properties into SQL; properties.json was kept unchanged.'):format(count))
    end
    initialized = true
end

local function load()
    assert(initialized, 'Property SQL storage is not initialized')
    loaded = false

    local rows = MySQL.query.await('SELECT `id`, `data` FROM `esx_properties` ORDER BY `id`')
    assert(type(rows) == 'table', 'Could not read properties from SQL')

    local properties, nextPersisted = {}, {}

    for index, row in ipairs(rows) do
        local id = tonumber(row.id)
        assert(id == index, 'SQL property IDs must be contiguous; refusing to renumber properties')

        local ok, property = pcall(json.decode, row.data)
        assert(ok and type(property) == 'table', ('Invalid SQL data for property %d'):format(id))

        property.plysinside = {}
        properties[id] = property
        nextPersisted[id] = encodeProperty(property)
    end

    persisted, loaded = nextPersisted, true

    return properties
end

local function save(properties, dirtyIds)
    assert(initialized and loaded, 'Refusing to save properties before a successful SQL load')

    local changes, removed, queries = {}, {}, {}

    if dirtyIds then
        assert(type(properties) == 'table' and type(dirtyIds) == 'table', 'Invalid property save request')
        
        for id in pairs(dirtyIds) do
            assert(type(id) == 'number' and id >= 1 and id <= #properties and id % 1 == 0
                and type(properties[id]) == 'table', 'Invalid dirty property ID; structural changes require a full save')

            local encoded = encodeProperty(properties[id])

            if encoded ~= persisted[id] then changes[id] = encoded end
        end
    else
        local snapshot, count = normalizeProperties(properties)

        for id = 1, count do
            local encoded = encodeProperty(snapshot[id])

            if encoded ~= persisted[id] then changes[id] = encoded end
        end

        for id in pairs(persisted) do
            if not snapshot[id] then removed[#removed + 1] = id end
        end
    end

    addUpserts(queries, changes, true)
    table.sort(removed)

    for start = 1, #removed, batchRows do
        local marks, values = {}, {}

        for index = start, math.min(start + batchRows - 1, #removed) do
            marks[#marks + 1], values[#values + 1] = '?', removed[index]
        end

        queries[#queries + 1] = {
            query = 'DELETE FROM `esx_properties` WHERE `id` IN (' .. table.concat(marks, ', ') .. ')', values = values,
        }
    end

    if #queries == 0 then
        return true
    end

    if MySQL.transaction.await(queries) ~= true then
        return false, 'Property SQL save transaction failed'
    end

    for id, encoded in pairs(changes) do persisted[id] = encoded end

    for _, id in ipairs(removed) do persisted[id] = nil end

    return true
end

local function withStorageLock(action, ...)
    while busy do Wait(0) end

    busy = true
    local result = table.pack(pcall(action, ...))
    busy = false

    if not result[1] then error(result[2], 0) end

    return table.unpack(result, 2, result.n)
end

function PropertyStorage.initialize(prepare) return withStorageLock(initialize, prepare) end

function PropertyStorage.load() return withStorageLock(load) end

function PropertyStorage.save(properties, dirtyIds) return withStorageLock(save, properties, dirtyIds) end
