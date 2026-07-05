-- Initiate the database if it already doesn't exist.
local function initDB()
	--  BANS TABLE
	MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS bans (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(64) NOT NULL,
            reason TEXT,
            banned_by VARCHAR(64),
            expires_at DATETIME NULL,
            banned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

            INDEX idx_bans_identifier (identifier),
            INDEX idx_bans_expires (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

	--  KICKS TABLE
	MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS kicks (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(64) NOT NULL,
            reason TEXT,
            kicked_by VARCHAR(64),
            kicked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

            INDEX idx_kicks_identifier (identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

	local hasBannedAt = MySQL.scalar.await(
		[[SELECT COUNT(*)
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = 'bans'
			AND COLUMN_NAME = 'banned_at']]
	)

	if tonumber(hasBannedAt) == 0 then
		MySQL.query.await("ALTER TABLE bans ADD COLUMN banned_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP")
	end

	MySQL.update.await([[
		UPDATE bans
		SET banned_at = CURRENT_TIMESTAMP
		WHERE banned_at IS NULL
			OR CAST(banned_at AS CHAR) = ''
			OR CAST(banned_at AS CHAR) = '0000-00-00 00:00:00'
	]])

	MySQL.update.await([[
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
	initDB()
	BanCache.load()
end)
