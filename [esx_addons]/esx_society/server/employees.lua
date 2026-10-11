-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

SocietyEmployees = {}

local pageSize = 50
local schemaPending = true
local schemaError = nil

function SocietyEmployees.ensureIndex()
    local indexed = MySQL.scalar.await([[
        SELECT COUNT(*) FROM (
            SELECT INDEX_NAME FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
            GROUP BY INDEX_NAME
            HAVING SUBSTRING_INDEX(GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX), ',', 3)
                    = 'job,job_grade,identifier'
                AND SUM(SUB_PART IS NOT NULL) = 0
        ) AS employee_indexes
    ]])

    assert(tonumber(indexed), 'Unable to inspect employee indexes')

    if tonumber(indexed) == 0 then
        MySQL.query.await(
            'CREATE INDEX `esx_society_employees` ON `users` (`job`, `job_grade`, `identifier`)'
        )
    end
end

MySQL.ready(function()
    ESXCatalog.awaitReady()

    local ok, err = pcall(SocietyEmployees.ensureIndex)

    schemaError = not ok and tostring(err) or nil
    schemaPending = false

    if schemaError then
        print(('[esx_society] Employee index migration failed: %s'):format(schemaError))
    end
end)

local function followsCursor(employee, cursor)
    return not cursor.identifier
        or employee.job.grade < cursor.grade
        or (employee.job.grade == cursor.grade and employee.identifier < cursor.identifier)
end

local function makeCursor(phase, employee)
    return {
        phase = phase,
        grade = employee.job.grade,
        identifier = employee.identifier,
    }
end

local function validCursor(cursor)
    if cursor == nil or cursor == false then
        return true
    end

    if type(cursor) ~= 'table' or (cursor.phase ~= 'online' and cursor.phase ~= 'offline') then
        return false
    end

    if cursor.identifier == nil then
        return cursor.phase == 'offline' and cursor.grade == nil
    end

    return type(cursor.identifier) == 'string'
        and #cursor.identifier > 0
        and #cursor.identifier <= 60
        and type(cursor.grade) == 'number'
        and cursor.grade == math.floor(cursor.grade)
        and cursor.grade >= 0
        and cursor.grade <= 2147483647
end

function SocietyEmployees.getPage(society, cursor)
    if not validCursor(cursor) then
        return {}, nil
    end

    while schemaPending do
        Wait(0)
    end

    assert(not schemaError, schemaError)

    local definition = ESX.GetJobs()[society]

    if not definition then
        return {}, nil
    end

    cursor = cursor or { phase = 'online' }

    local employees = {}

    if cursor.phase == 'online' then
        for _, player in ipairs(ESX.ExtendedPlayers('job', society)) do
            local job = player.getJob()
            local name = player.getName()

            if Config.EnableESXIdentity and name == GetPlayerName(player.src) then
                local firstName = player.get('firstName') or ''
                local lastName = player.get('lastName') or ''

                name = firstName .. ' ' .. lastName
            end

            local employee = {
                name = name,
                identifier = player.getIdentifier(),
                job = {
                    name = society,
                    label = job.label,
                    grade = job.grade,
                    grade_name = job.grade_name,
                    grade_label = job.grade_label,
                },
            }

            if followsCursor(employee, cursor) then
                employees[#employees + 1] = employee
            end
        end

        table.sort(employees, function(a, b)
            if a.job.grade == b.job.grade then
                return a.identifier > b.identifier
            end

            return a.job.grade > b.job.grade
        end)

        if #employees >= pageSize then
            local nextCursor = #employees > pageSize and makeCursor('online', employees[pageSize])
                or { phase = 'offline' }

            for i = #employees, pageSize + 1, -1 do
                employees[i] = nil
            end

            return employees, nextCursor
        end

        cursor = { phase = 'offline' }
    end

    local columns = 'identifier, job_grade'

    if Config.EnableESXIdentity then
        columns = columns .. ', firstname, lastname'
    end

    local query = 'SELECT ' .. columns .. ' FROM `users` WHERE `job` = ?'
    local parameters = { society }

    if cursor.identifier then
        query = query .. ' AND (job_grade < ? OR (job_grade = ? AND identifier < ?))'
        parameters[#parameters + 1] = cursor.grade
        parameters[#parameters + 1] = cursor.grade
        parameters[#parameters + 1] = cursor.identifier
    end

    query = query .. ' ORDER BY job_grade DESC, identifier DESC LIMIT ?'

    local remaining = pageSize - #employees

    parameters[#parameters + 1] = remaining + 1

    local rows = MySQL.query.await(query, parameters)

    assert(type(rows) == 'table', 'Unable to read employees')

    local nextCursor = nil

    for i = 1, math.min(#rows, remaining) do
        local row = rows[i]
        local gradeNumber = tonumber(row.job_grade)
        local grade = gradeNumber and definition.grades[tostring(math.floor(gradeNumber))]

        if not ESX.GetPlayerFromIdentifier(row.identifier) and grade then
            local name = TranslateCap('name_not_found')

            if Config.EnableESXIdentity then
                local firstName = row.firstname or ''
                local lastName = row.lastname or ''

                if firstName ~= '' or lastName ~= '' then
                    name = firstName .. ' ' .. lastName
                end
            end

            employees[#employees + 1] = {
                name = name,
                identifier = row.identifier,
                job = {
                    name = society,
                    label = definition.label,
                    grade = gradeNumber,
                    grade_name = grade.name,
                    grade_label = grade.label,
                },
            }
        end

        if #rows > remaining then
            nextCursor = {
                phase = 'offline',
                grade = tonumber(row.job_grade),
                identifier = row.identifier,
            }
        end
    end

    return employees, nextCursor
end
