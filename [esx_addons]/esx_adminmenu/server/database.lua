-- Initiate the database if it already doesn't exist.
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

	--  ADMIN ACTION LOG
	-- Replaces the former `kicks` table, which was written to but never read
	-- back by anything. Any existing `kicks` table is deliberately left in
	-- place: a resource dropping tables on start is a footgun.
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
            INDEX idx_admin_logs_created (created_at)
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
		Helpers.safeQuery("ALTER TABLE bans ADD COLUMN banned_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP")
	end

	local hasIdentifiers = Helpers.safeScalar(
		[[SELECT COUNT(*)
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = 'bans'
			AND COLUMN_NAME = 'identifiers']]
	)

	if tonumber(hasIdentifiers) == 0 then
		Helpers.safeQuery("ALTER TABLE bans ADD COLUMN identifiers TEXT NULL")
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
	print("[esx-adminmenu] Database tables checked/created!")
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
