-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Initiate / migrate the database schema.

local function indexExists(tableName, indexName)
	local count = Helpers.safeScalar(
		[[SELECT COUNT(*)
		FROM INFORMATION_SCHEMA.STATISTICS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = ?
			AND INDEX_NAME = ?]],
		{ tableName, indexName }
	)

	return tonumber(count) and tonumber(count) > 0
end

local function indexStartsWith(tableName, columns)
	local rows = Helpers.safeQuery(
		[[SELECT INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME
		FROM INFORMATION_SCHEMA.STATISTICS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = ?
			AND SEQ_IN_INDEX <= ?
		ORDER BY INDEX_NAME, SEQ_IN_INDEX]],
		{ tableName, #columns }
	)

	if type(rows) ~= "table" then
		return false
	end

	local indexes = {}
	for i = 1, #rows do
		local row = rows[i]
		local indexName = row.INDEX_NAME or row.index_name
		local sequence = tonumber(row.SEQ_IN_INDEX or row.seq_in_index)
		local column = row.COLUMN_NAME or row.column_name

		if indexName and sequence and column then
			indexes[indexName] = indexes[indexName] or {}
			indexes[indexName][sequence] = column
		end
	end

	for _, indexedColumns in pairs(indexes) do
		local matches = true

		for i = 1, #columns do
			if indexedColumns[i] ~= columns[i] then
				matches = false
				break
			end
		end

		if matches then
			return true
		end
	end

	return false
end

local function ensureOwnedVehicleSearchIndex(indexName, definition, columns)
	if indexExists("owned_vehicles", indexName) or indexStartsWith("owned_vehicles", columns) then
		return
	end

	print(("[esx-adminmenu] Creating owned_vehicles search index %s..."):format(indexName))

	local result = Helpers.safeQuery(("ALTER TABLE owned_vehicles ADD INDEX %s %s"):format(indexName, definition))

	if result == nil then
		print(("[esx-adminmenu] Failed to create %s"):format(indexName))
	else
		print(("[esx-adminmenu] Created %s"):format(indexName))
	end
end

local function ensureUserSearchIndexes()
	if not indexExists("users", "idx_adminmenu_first_last") then
		print("[esx-adminmenu] Creating users firstname/lastname search index...")

		local result = Helpers.safeQuery([[
			ALTER TABLE users
			ADD INDEX idx_adminmenu_first_last (firstname, lastname)
		]])

		if result == nil then
			print("[esx-adminmenu] Failed to create idx_adminmenu_first_last")
		else
			print("[esx-adminmenu] Created idx_adminmenu_first_last")
		end
	end

	if not indexExists("users", "idx_adminmenu_last_first") then
		print("[esx-adminmenu] Creating users lastname/firstname search index...")

		local result = Helpers.safeQuery([[
			ALTER TABLE users
			ADD INDEX idx_adminmenu_last_first (lastname, firstname)
		]])

		if result == nil then
			print("[esx-adminmenu] Failed to create idx_adminmenu_last_first")
		else
			print("[esx-adminmenu] Created idx_adminmenu_last_first")
		end
	end

	if not indexExists("users", "idx_adminmenu_phone") then
		print("[esx-adminmenu] Creating users phone search index...")

		local result = Helpers.safeQuery([[
			ALTER TABLE users
			ADD INDEX idx_adminmenu_phone (phone_number)
		]])

		if result == nil then
			print("[esx-adminmenu] Failed to create idx_adminmenu_phone")
		else
			print("[esx-adminmenu] Created idx_adminmenu_phone")
		end
	end
end

local function ensureOwnedVehicleSearchIndexes()
	ensureOwnedVehicleSearchIndex("idx_adminmenu_owned_plate", "(plate)", { "plate" })
	ensureOwnedVehicleSearchIndex("idx_adminmenu_owned_owner_plate", "(owner, plate)", { "owner", "plate" })
	ensureOwnedVehicleSearchIndex("idx_adminmenu_owned_type_plate", "(type, plate)", { "type", "plate" })
end

local function ensureAdminLogSearchIndexes()
    if not indexExists("admin_logs", "idx_admin_logs_actor_name") then
        print("[esx-adminmenu] Creating admin_logs actor name index...")

        local result = Helpers.safeQuery([[
            ALTER TABLE admin_logs
            ADD INDEX idx_admin_logs_actor_name (actor_name)
        ]])

        if result == nil then
            print("[esx-adminmenu] Failed to create idx_admin_logs_actor_name")
        else
            print("[esx-adminmenu] Created idx_admin_logs_actor_name")
        end
    end

    if not indexExists("admin_logs", "idx_admin_logs_target_name") then
        print("[esx-adminmenu] Creating admin_logs target name index...")

        local result = Helpers.safeQuery([[
            ALTER TABLE admin_logs
            ADD INDEX idx_admin_logs_target_name (target_name)
        ]])

        if result == nil then
            print("[esx-adminmenu] Failed to create idx_admin_logs_target_name")
        else
            print("[esx-adminmenu] Created idx_admin_logs_target_name")
        end
    end

    if not indexExists("admin_logs", "idx_admin_logs_action_only") then
        print("[esx-adminmenu] Creating admin_logs action index...")

        local result = Helpers.safeQuery([[
            ALTER TABLE admin_logs
            ADD INDEX idx_admin_logs_action_only (action)
        ]])

        if result == nil then
            print("[esx-adminmenu] Failed to create idx_admin_logs_action_only")
        else
            print("[esx-adminmenu] Created idx_admin_logs_action_only")
        end
    end

    if not indexExists("admin_logs", "idx_admin_logs_created_id") and not indexStartsWith("admin_logs", { "created_at", "id" }) then
        print("[esx-adminmenu] Creating admin_logs retention index...")

        local result = Helpers.safeQuery([[
            ALTER TABLE admin_logs
            ADD INDEX idx_admin_logs_created_id (created_at, id)
        ]])

        if result == nil then
            print("[esx-adminmenu] Failed to create idx_admin_logs_created_id")
        else
            print("[esx-adminmenu] Created idx_admin_logs_created_id")
        end
    end
end

local function initDB()
	--  BANS TABLE
	Helpers.safeQuery([[
		CREATE TABLE IF NOT EXISTS bans (
			id INT AUTO_INCREMENT PRIMARY KEY,
			identifier VARCHAR(64) NOT NULL,
			identifiers TEXT NULL,
			reason TEXT,
			banned_by VARCHAR(64),
			expires_at DATETIME NULL,
			banned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

			INDEX idx_bans_identifier (identifier),
			INDEX idx_bans_expires (expires_at)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	]])

	-- ADMIN ACTION LOG
	-- Replaces the former `kicks` table, which was written to but never
	-- read back by anything. Any existing `kicks` table is deliberately
	-- left in place: a resource dropping tables on start is a footgun.
	Helpers.safeQuery([[
		CREATE TABLE IF NOT EXISTS admin_logs (
			id INT AUTO_INCREMENT PRIMARY KEY,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			actor_identifier VARCHAR(64) NOT NULL,
			actor_name VARCHAR(64) NULL,
			namespace VARCHAR(32) NOT NULL,
			action VARCHAR(64) NOT NULL,
			target_identifier VARCHAR(64) NULL,
			target_name VARCHAR(64) NULL,
			success TINYINT(1) NOT NULL DEFAULT 1,
			error VARCHAR(191) NULL,
			payload TEXT NULL,

			INDEX idx_admin_logs_actor (actor_identifier),
			INDEX idx_admin_logs_target (target_identifier),
			INDEX idx_admin_logs_action (namespace, action),
			INDEX idx_admin_logs_created (created_at),
			INDEX idx_admin_logs_created_id (created_at, id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	]])
	
	local hasBannedAt = Helpers.safeScalar(
		[[SELECT COUNT(*)
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = 'bans'
			AND COLUMN_NAME = 'banned_at']]
	)

	if tonumber(hasBannedAt) == 0 then
		Helpers.safeQuery([[
			ALTER TABLE bans
			ADD COLUMN banned_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
		]])
	end

	local hasIdentifiers = Helpers.safeScalar(
		[[SELECT COUNT(*)
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = 'bans'
			AND COLUMN_NAME = 'identifiers']]
	)

	if tonumber(hasIdentifiers) == 0 then
		Helpers.safeQuery([[
			ALTER TABLE bans
			ADD COLUMN identifiers TEXT NULL
		]])
	end

	Helpers.safeUpdate([[
		UPDATE bans
		SET banned_at = CURRENT_TIMESTAMP
		WHERE banned_at IS NULL
			OR CAST(banned_at AS CHAR) = ''
			OR CAST(banned_at AS CHAR) = '0000-00-00 00:00:00'
	]])

	Helpers.safeUpdate([[
		UPDATE bans
		SET identifier = CONCAT('license:', identifier)
		WHERE identifier IS NOT NULL
			AND identifier <> ''
			AND identifier NOT LIKE '%:%'
	]])

	ensureUserSearchIndexes()
	ensureOwnedVehicleSearchIndexes()
	ensureAdminLogSearchIndexes()

	print("[esx-adminmenu] Database tables/indexes checked/created!")
end

AddEventHandler("onResourceStart", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	-- Isolate schema setup from cache warmup: a failed migration must not
	-- prevent ban enforcement from loading (and vice versa).
	pcall(initDB)
	pcall(BanCache.load)
end)
