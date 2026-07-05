---@param src number
---@param xPlayer table
AddEventHandler('esx:playerLoaded', function(src, xPlayer)
	local status = MySQL.scalar.await('SELECT `status` FROM `users` WHERE `identifier` = ? LIMIT 1', { xPlayer.getIdentifier() })

	status = status and json.decode(status) or {}
	xPlayer.set('status', status)

	TriggerClientEvent('esx_status:load', xPlayer.source, status)
end)

---@param src number
---@param reason string
AddEventHandler('esx:playerDropped', function(src, reason)
	local xPlayer = ESX.Player(src)
	if not xPlayer then
		return
	end

	local status = xPlayer.get('status') or {}
	MySQL.update('UPDATE users SET status = ? WHERE identifier = ?', { json.encode(status), xPlayer.getIdentifier() })
end)

---@param src number
---@param statusName string
---@param cb function|table
AddEventHandler('esx_status:getStatus', function(src, statusName, cb)
	local xPlayer = ESX.Player(src)
	if not xPlayer then
		return
	end

	local status = xPlayer.get('status') or {}
	for i = 1, #status do
		if type(status[i]) == 'table' and status[i].name == statusName then
			return cb(status[i])
		end
	end
end)

---@param status table
RegisterNetEvent('esx_status:update', function(status)
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return
	end

	if type(status) ~= 'table' then
		return
	end

	local merged, index = {}, {}
	local current = xPlayer.get('status') or {}

	for i = 1, #current do
		local entry = current[i]
		if type(entry) == 'table' and type(entry.name) == 'string' then
			local copy = { name = entry.name, val = entry.val, percent = entry.percent }
			merged[#merged + 1] = copy
			index[entry.name] = copy
		end
	end

	for i = 1, #status do
		local entry = status[i]
		if type(entry) == 'table' and type(entry.name) == 'string' and type(entry.val) == 'number' and entry.val == entry.val then
			local val = entry.val
			if val < 0 then
				val = 0
			elseif val > Config.StatusMax then
				val = Config.StatusMax
			end

			local existing = index[entry.name]
			if existing then
				if type(existing.val) ~= 'number' or val < existing.val then
					existing.val = val
					existing.percent = (val / Config.StatusMax) * 100
				end
			else
				local copy = { name = entry.name, val = val, percent = (val / Config.StatusMax) * 100 }
				merged[#merged + 1] = copy
				index[entry.name] = copy
			end
		end
	end

	xPlayer.set('status', merged)
end)
