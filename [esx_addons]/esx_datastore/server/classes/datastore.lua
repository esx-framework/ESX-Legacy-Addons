-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function stringsplit(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end

	local t = {}
	local i = 1

	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end

	return t
end

function CreateDataStore(name, owner, data)
	local self = {}

	self.name  = name
	self.owner = owner
	if type(data) == 'string' then
		local ok, decoded = pcall(json.decode, data)

		data = ok and decoded or nil
	end

	self.data = type(data) == 'table' and data or {}

	local timeoutCallback
	local revision = 0
	local persisted = 0
	local writing = false
	local scheduleSave

	function self.set(key, val)
		if type(key) ~= 'string' or key == '' then
			return false
		end

		self.data[key] = val
		self.save()
	end

	function self.get(key, i)
		if type(key) ~= 'string' or key == '' then
			return nil
		end

		local obj = self.data

		if type(obj) ~= 'table' then
			return nil
		end

		if key:find('.', 1, true) then
			for segment in key:gmatch('[^.]+') do
				if type(obj) ~= 'table' then
					return nil
				end

				obj = obj[segment]
			end
		else
			obj = obj[key]
		end

		if i == nil then
			return obj
		elseif type(obj) == 'table' then
			return obj[i]
		end
	end

	function self.count(key, i)
		local obj = self.get(key, i)

		if type(obj) == 'table' then
			return #obj
		end

		return 0
	end

	function self.isDirty()
		return persisted ~= revision or writing
	end

	function self.flush()
		if timeoutCallback then
			xLib.timeout.clearTimeout(timeoutCallback)
			timeoutCallback = nil
		end

		while writing do
			Wait(0)
		end

		while persisted ~= revision do
			writing = true
			local version = revision

			local ok, result = pcall(function()
				local snapshot = json.encode(self.data)

				if self.owner == nil then
					return MySQL.update.await(
						'UPDATE datastore_data SET data = ? WHERE name = ?',
						{ snapshot, self.name }
					)
				end

				return MySQL.update.await(
					'UPDATE datastore_data SET data = ? WHERE name = ? and owner = ?',
					{ snapshot, self.name, self.owner }
				)
			end)

			writing = false

			if not ok or type(result) ~= 'number' or result < 0 then
				print(('[esx_datastore] Save failed for %s: %s'):format(self.name, tostring(result)))
				scheduleSave()
				return false
			end

			persisted = version
		end

		return true
	end

	scheduleSave = function()
		if timeoutCallback then
			xLib.timeout.clearTimeout(timeoutCallback)
		end

		timeoutCallback = xLib.timeout.setTimeout(10000, function()
			timeoutCallback = nil
			self.flush()
		end)
	end

	function self.save()
		revision = revision + 1
		scheduleSave()
	end

	return self
end
