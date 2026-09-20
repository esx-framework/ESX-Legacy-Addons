-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework


local Jobs = setmetatable({}, {__index = function(_, key)
	return ESX.GetJobs()[key]
end
})
local RegisteredSocieties = {}
local SocietiesByName = {}
local gradeUpdateLimiters = {}

local function getValidAmount(amount)
	amount = tonumber(amount)
	if not amount then
		return nil
	end

	amount = ESX.Math.Round(amount)
	if amount <= 0 then
		return nil
	end

	return amount
end

local function getValidSalary(salary)
	salary = tonumber(salary)
	if not salary or salary ~= math.floor(salary) then
		return nil
	end

	if salary < 0 or salary > Config.MaxSalary then
		return nil
	end

	return salary
end

local function getValidJobGradeLabel(label)
	if type(label) ~= 'string' then
		return nil
	end

	label = ESX.Math.Trim(label:gsub('[%c]', ' ')):sub(1, Config.MaxJobGradeLabelLength or 40)
	label = ESX.Math.Trim(label)

	if label == '' then
		return nil
	end

	return label
end

local function decodeJsonObject(value, fallback)
	if type(value) == 'table' then
		return value
	end

	if type(value) ~= 'string' or value == '' then
		return fallback
	end

	local ok, decoded = pcall(json.decode, value)
	if not ok or type(decoded) ~= 'table' then
		return fallback
	end

	return decoded
end

local function isGradeUpdateLimited(source, job, action)
	local cooldown = Config.JobGradeUpdateCooldown or 1500
	if cooldown <= 0 then
		return false
	end

	local limiter = gradeUpdateLimiters[action]
	if not limiter then
		limiter = xLib.rateLimiter({
			capacity = 1,
			refill = 1,
			interval = cooldown,
			staleMs = math.max(60000, cooldown * 4)
		})
		gradeUpdateLimiters[action] = limiter
	end

	local allowed = limiter:consume(('%s:%s'):format(source, job))
	return not allowed
end

local function refreshJobOrFallback(job)
	if ESX.IsFunctionReference(ESX.RefreshJob) and ESX.RefreshJob(job) then
		return true
	end

	print(('[^3WARNING^7] Failed to refresh job ^5%s^7, falling back to RefreshJobs!'):format(tostring(job)))

	if ESX.IsFunctionReference(ESX.RefreshJobs) then
		ESX.RefreshJobs()
	end

	return Jobs[job] ~= nil
end

local function isBoss(xPlayer)
	local job = xPlayer and xPlayer.getJob()
	return job and Config.BossGrades[job.grade_name] and true or false
end

local function hasSocietyBossAccess(xPlayer, society)
	local job = xPlayer and xPlayer.getJob()
	return job and society and job.name == society.name and Config.BossGrades[job.grade_name] and true or false
end

local function normalizePlate(plate)
	return xLib.vehiclePlate.normalize(plate, {
		maxLength = 12
	})
end

local getPlayerCoords = xLib.player.getCoords

local function toVector3(coords)
	if not coords then return nil end
	if type(coords) == 'vector3' then return coords end
	if coords.x and coords.y and coords.z then return vector3(coords.x, coords.y, coords.z) end

	return nil
end

local function isNearSocietyGarage(source, societyName)
	local coords = getPlayerCoords(source)
	local zones = Config.SocietyGarageZones and Config.SocietyGarageZones[societyName]

	if not coords or type(zones) ~= 'table' then return false end

	for i=1, #zones do
		local zoneCoords = toVector3(zones[i])
		if zoneCoords and #(coords - zoneCoords) <= (Config.SocietyGarageDistance or 12.0) then
			return true
		end
	end

	return false
end

local function canAccessSocietyGarage(source, society)
	local xPlayer = ESX.Player(source)
	local job = xPlayer and xPlayer.getJob()

	if not job or not society or job.name ~= society.name then
		return false
	end

	return isNearSocietyGarage(source, society.name)
end

local function validateGarageVehicle(vehicle)
	if type(vehicle) ~= 'table' then return false end

	local plate = normalizePlate(vehicle.plate)
	if not plate then return false end

	if vehicle.model ~= nil and type(vehicle.model) ~= 'number' and type(vehicle.model) ~= 'string' then
		return false
	end

	vehicle.plate = plate
	return true
end

local function getValidJobGrade(job, grade)
	grade = tonumber(grade)
	if not grade or grade ~= math.floor(grade) then
		return nil
	end

	if not Jobs[job] or not Jobs[job].grades[tostring(grade)] then
		return nil
	end

	return grade
end

function GetSociety(name)
	return SocietiesByName[name]
end
exports("GetSociety", GetSociety)

function registerSociety(name, label, account, datastore, inventory, data)
	if SocietiesByName[name] then
		print(('[^3WARNING^7] society already registered, name: ^5%s^7'):format(name))
		return
	end

	local society = {
		name = name,
		label = label,
		account = account,
		datastore = datastore,
		inventory = inventory,
		data = data
	}

	SocietiesByName[name] = society
	table.insert(RegisteredSocieties, society)
end
AddEventHandler('esx_society:registerSociety', registerSociety)
exports("registerSociety", registerSociety)

AddEventHandler('esx_society:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('esx_society:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

RegisterServerEvent('esx_society:checkSocietyBalance')
AddEventHandler('esx_society:checkSocietyBalance', function(society)
	local xPlayer = ESX.Player(source)
	local society = GetSociety(society)

	if not hasSocietyBossAccess(xPlayer, society) then
		print(('esx_society: %s attempted to call checkSocietyBalance!'):format(source))
		return
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		TriggerClientEvent("esx:showNotification", xPlayer.src, TranslateCap('check_balance', ESX.Math.GroupDigits(account.money)))
	end)
end)

RegisterServerEvent('esx_society:withdrawMoney')
AddEventHandler('esx_society:withdrawMoney', function(societyName, amount)
	local source = source
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to withdraw from non-existing society - ^5%s^7!'):format(source, societyName))
		return
	end
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return
	end

	amount = getValidAmount(amount)
	if not amount then
		return xPlayer.showNotification(TranslateCap('invalid_amount'))
	end

	if not hasSocietyBossAccess(xPlayer, society) then
		return print(('[^3WARNING^7] Player ^5%s^7 attempted to withdraw from society - ^5%s^7!'):format(source, society.name))
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		if not account then
			return print(('[^3WARNING^7] Society ^5%s^7 has no shared account!'):format(society.name))
		end

		if account.money >= amount then
			account.removeMoney(amount)
			xPlayer.addMoney(amount, TranslateCap('money_add_reason'))
			xPlayer.showNotification(TranslateCap('have_withdrawn', ESX.Math.GroupDigits(amount)))
		else
			xPlayer.showNotification(TranslateCap('invalid_amount'))
		end
	end)
end)

RegisterServerEvent('esx_society:depositMoney')
AddEventHandler('esx_society:depositMoney', function(societyName, amount)
	local source = source
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return
	end

	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to deposit to non-existing society - ^5%s^7!'):format(source, societyName))
		return
	end
	amount = getValidAmount(amount)
	if not amount then
		return xPlayer.showNotification(TranslateCap('invalid_amount'))
	end

	if xPlayer.getJob().name ~= society.name then
		return print(('[^3WARNING^7] Player ^5%s^7 attempted to deposit to society - ^5%s^7!'):format(source, society.name))
	end
	if xPlayer.getMoney() >= amount then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			if not account then
				return print(('[^3WARNING^7] Society ^5%s^7 has no shared account!'):format(society.name))
			end

			xPlayer.removeMoney(amount, TranslateCap('money_remove_reason'))
			xPlayer.showNotification(TranslateCap('have_deposited', ESX.Math.GroupDigits(amount)))
			account.addMoney(amount)
		end)
	else
		xPlayer.showNotification(TranslateCap('invalid_amount'))
	end
end)

RegisterServerEvent('esx_society:washMoney')
AddEventHandler('esx_society:washMoney', function(society, amount)
	local source = source
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		return
	end

	local account = xPlayer.getAccount('black_money')
	amount = getValidAmount(amount)
	local registeredSociety = GetSociety(society)

	if not amount then
		return xPlayer.showNotification(TranslateCap('invalid_amount'))
	end

	if not registeredSociety or not hasSocietyBossAccess(xPlayer, registeredSociety) then
		return print(('[^3WARNING^7] Player ^5%s^7 attempted to wash money in society - ^5%s^7!'):format(source, society))
	end
	if account.money >= amount then
		xPlayer.removeAccountMoney('black_money', amount, "Washing")

		MySQL.insert('INSERT INTO society_moneywash (identifier, society, amount) VALUES (?, ?, ?)', {xPlayer.getIdentifier(), society, amount},
		function(rowsChanged)
			xPlayer.showNotification(TranslateCap('you_have', ESX.Math.GroupDigits(amount)))
		end)
	else
		xPlayer.showNotification(TranslateCap('invalid_amount'))
	end
end)

RegisterServerEvent('esx_society:putVehicleInGarage')
AddEventHandler('esx_society:putVehicleInGarage', function(societyName, vehicle)
	local source = source
	local society = GetSociety(societyName)
	if not society or not canAccessSocietyGarage(source, society) or not validateGarageVehicle(vehicle) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to put vehicle in non-existing society garage - ^5%s^7!'):format(source, societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		for i=1, #garage do
			if normalizePlate(garage[i].plate) == vehicle.plate then
				return
			end
		end

		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('esx_society:removeVehicleFromGarage')
AddEventHandler('esx_society:removeVehicleFromGarage', function(societyName, vehicle)
	local source = source
	local society = GetSociety(societyName)
	if not society or not canAccessSocietyGarage(source, society) or not validateGarageVehicle(vehicle) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to remove vehicle from non-existing society garage - ^5%s^7!'):format(source, societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		for i=1, #garage, 1 do
			if normalizePlate(garage[i].plate) == vehicle.plate then
				table.remove(garage, i)
				break
			end
		end

		store.set('garage', garage)
	end)
end)

xLib.callback.registerCompat('esx_society:getSocietyMoney', function(source, cb, societyName)
	local society = GetSociety(societyName)
	local xPlayer = ESX.Player(source)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to get money from non-existing society - ^5%s^7!'):format(source, societyName))
		return cb(0)
	end
	if not hasSocietyBossAccess(xPlayer, society) then return cb(0) end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		cb(account.money or 0)
	end)
end)

xLib.callback.registerCompat('esx_society:getEmployees', function(source, cb, society)
	local registeredSociety = GetSociety(society)
	local xPlayer = ESX.Player(source)

	if not hasSocietyBossAccess(xPlayer, registeredSociety) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to read employees for society - ^5%s^7!'):format(source, tostring(society)))
		return cb({})
	end

	local employees = {}

	local xPlayers = ESX.ExtendedPlayers('job', society)

	for i=1, #(xPlayers) do 
		local xPlayer = xPlayers[i]

		local name = xPlayer.getName()
		if Config.EnableESXIdentity and name == GetPlayerName(xPlayer.src) then
			name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
		end

		local job = xPlayer.getJob()

		table.insert(employees, {
			name = name,
			identifier = xPlayer.getIdentifier(),
			job = {
				name = society,
				label = job.label,
				grade = job.grade,
				grade_name = job.grade_name,
				grade_label = job.grade_label
			}
		})
	end
		
	local query = "SELECT identifier, job_grade FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"

	if Config.EnableESXIdentity then
		query = "SELECT identifier, job_grade, firstname, lastname FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"
	end

	MySQL.query(query, {society},
	function(result)
		for k, row in pairs(result) do
			local alreadyInTable
			local identifier = row.identifier

			for k, v in pairs(employees) do
				if v.identifier == identifier then
					alreadyInTable = true
				end
			end

			if not alreadyInTable then
				local name = TranslateCap('name_not_found')

				if Config.EnableESXIdentity then
					name = row.firstname .. ' ' .. row.lastname 
				end
				
				table.insert(employees, {
					name = name,
					identifier = identifier,
					job = {
						name = society,
						label = Jobs[society].label,
						grade = row.job_grade,
						grade_name = Jobs[society].grades[tostring(row.job_grade)].name,
						grade_label = Jobs[society].grades[tostring(row.job_grade)].label
					}
				})
			end
		end

		cb(employees)
	end)

end)

xLib.callback.registerCompat('esx_society:getJob', function(source, cb, society)
	if not Jobs[society] then
		return cb(false)
	end

	local job = json.decode(json.encode(Jobs[society]))
	local grades = {}

	for k,v in pairs(job.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	job.grades = grades

	cb(job)
end)

xLib.callback.registerCompat('esx_society:setJob', function(source, cb, identifier, job, grade, actionType)
	local xPlayer = ESX.Player(source)
	local xPlayerJob = xPlayer and xPlayer.getJob()
	local xTarget = ESX.Player(identifier)

	if not xPlayerJob or not isBoss(xPlayer) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob without boss access!'):format(source))
		return cb(false)
	end

	actionType = tostring(actionType or '')
	if actionType ~= 'hire' and actionType ~= 'promote' and actionType ~= 'fire' then
		print(('[^3WARNING^7] Player ^5%s^7 attempted invalid society action ^5%s^7!'):format(source, actionType))
		return cb(false)
	end

	if actionType == 'fire' then
		if job ~= 'unemployed' or tonumber(grade) ~= 0 then
			print(('[^3WARNING^7] Player ^5%s^7 attempted invalid fire job assignment - ^5%s:%s^7!'):format(source, tostring(job), tostring(grade)))
			return cb(false)
		end
		grade = 0
	else
		grade = getValidJobGrade(job, grade)
		if job ~= xPlayerJob.name or not grade or grade > xPlayerJob.grade then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to set invalid society job - ^5%s:%s^7!'):format(source, tostring(job), tostring(grade)))
			return cb(false)
		end
	end

	if not xTarget then
		if actionType == 'hire' then
			print(('[^3WARNING^7] Player ^5%s^7 attempted to hire offline player ^5%s^7!'):format(source, tostring(identifier)))
			return cb(false)
		end

		MySQL.single('SELECT job FROM users WHERE identifier = ?', {identifier}, function(result)
			if not result or result.job ~= xPlayerJob.name then
				print(('[^3WARNING^7] Player ^5%s^7 attempted to manage non-society offline player ^5%s^7!'):format(source, tostring(identifier)))
				return cb(false)
			end

			MySQL.update('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {job, grade, identifier}, function()
				cb(true)
			end)
		end)
		return
	end

	if actionType ~= 'hire' and xTarget.getJob().name ~= xPlayerJob.name then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to manage non-society player ^5%s^7!'):format(source, xTarget.src))
		return cb(false)
	end

	xTarget.setJob(job, grade)
	local xTargetName, xTargetJob = xTarget.getName(), xTarget.getJob()
	if actionType == 'hire' then
		xTarget.showNotification(TranslateCap('you_have_been_hired', job))
		xPlayer.showNotification(TranslateCap("you_have_hired", xTargetName))
	elseif actionType == 'promote' then
		xTarget.showNotification(TranslateCap('you_have_been_promoted'))
		xPlayer.showNotification(TranslateCap("you_have_promoted", xTargetName, xTargetJob.grade_label))
	elseif actionType == 'fire' then
		xTarget.showNotification(TranslateCap('you_have_been_fired', xTargetJob.label))
		xPlayer.showNotification(TranslateCap("you_have_fired", xTargetName))
	end

	cb(true)
end)


xLib.callback.registerCompat('esx_society:setJobSalary', function(source, cb, job, grade, salary)
	local xPlayer = ESX.Player(source)
	local xPlayerJob = xPlayer and xPlayer.getJob()
	grade = getValidJobGrade(job, grade)
	salary = getValidSalary(salary)

	if not xPlayerJob or xPlayerJob.name ~= job or not Config.BossGrades[xPlayerJob.grade_name] or not grade then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary for ^5%s^7!'):format(source, job))
		return cb(false)
	end

	if not salary then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary over the config limit for ^5%s^7!'):format(source, job))
		return cb(false)
	end

	if tonumber(Jobs[job].grades[tostring(grade)].salary) == salary then
		return cb(false)
	end

	if isGradeUpdateLimited(source, job, 'salary') then
		return cb(false)
	end

	MySQL.update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', {salary, job, grade}, function(rowsChanged)
		if rowsChanged ~= 1 then return cb(false) end

		cb(refreshJobOrFallback(job))
	end)
end)

xLib.callback.registerCompat('esx_society:setJobLabel', function(source, cb, job, grade, label)
	local xPlayer = ESX.Player(source)
	local xPlayerJob = xPlayer and xPlayer.getJob()
	grade = getValidJobGrade(job, grade)
	label = getValidJobGradeLabel(label)

	if not xPlayerJob or xPlayerJob.name ~= job or not Config.BossGrades[xPlayerJob.grade_name] or not grade or not label then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobLabel for ^5%s^7!'):format(source, job))
		return cb(false)
	end

	if Jobs[job].grades[tostring(grade)].label == label then
		return cb(false)
	end

	if isGradeUpdateLimited(source, job, 'label') then
		return cb(false)
	end

	MySQL.update('UPDATE job_grades SET label = ? WHERE job_name = ? AND grade = ?', {label, job, grade}, function(rowsChanged)
		if rowsChanged ~= 1 then return cb(false) end

		cb(refreshJobOrFallback(job))
	end)
end)

local ALL_GRADES <const> = -1
local UNIFORM_COLUMNS <const> = {
	[0] = 'skin_male',
	[1] = 'skin_female'
}
local UNIFORM_PROP_DRAWABLES <const> = {
	helmet_1 = true,
	glasses_1 = true,
	watches_1 = true,
	bracelets_1 = true,
	ears_1 = true
}

local uniformSaveLimiter = xLib.rateLimiter({
	capacity = 1,
	refill = 1,
	interval = math.max(1, Config.UniformSaveCooldown or 30000),
	staleMs = math.max(60000, (Config.UniformSaveCooldown or 30000) * 4)
})
local uniformSaveInFlight = {}

local function getUniformComponentBounds(component)
	local limit = Config.UniformComponentLimits and Config.UniformComponentLimits[component]

	if limit then
		return limit.min or 0, limit.max or (Config.UniformDrawableMax or 2000)
	end

	if UNIFORM_PROP_DRAWABLES[component] then
		return -1, Config.UniformPropMax or 255
	end

	if component:sub(-2) == '_2' then
		return 0, Config.UniformTextureMax or 255
	end

	return 0, Config.UniformDrawableMax or 2000
end

local function getIdentitySex(xPlayer)
	local identitySex = xPlayer.get('sex')
	if type(identitySex) == 'string' then
		identitySex = identitySex:lower()
	end

	if identitySex == 'm' or identitySex == 0 then
		return 0
	elseif identitySex == 'f' or identitySex == 1 then
		return 1
	end

	return nil
end

---@param skin any
---@return table?
local function getValidUniform(skin)
	if type(skin) ~= 'table' or (skin.sex ~= 0 and skin.sex ~= 1) then
		return nil
	end

	local uniform = {}

	for i = 1, #Config.UniformComponents do
		local component = Config.UniformComponents[i]
		local value = skin[component]
		local min, max = getUniformComponentBounds(component)

		if type(value) ~= 'number' or value ~= math.floor(value) or value < min or value > max then
			return nil
		end

		uniform[component] = value
	end

	return uniform
end

---@param storedUniform string|table|nil
---@param uniform table
---@return boolean
local function isSameUniform(storedUniform, uniform)
	storedUniform = decodeJsonObject(storedUniform, {})

	for i = 1, #Config.UniformComponents do
		local component = Config.UniformComponents[i]

		if storedUniform[component] ~= uniform[component] then
			return false
		end
	end

	return true
end

xLib.callback.registerCompat('esx_society:setJobUniform', function(source, cb, job, grade, skin)
	local xPlayer = ESX.Player(source)
	local xPlayerJob = xPlayer and xPlayer.getJob()

	if not xPlayerJob or xPlayerJob.name ~= job or not Config.BossGrades[xPlayerJob.grade_name] then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobUniform for ^5%s^7!'):format(source, tostring(job)))
		return cb(false)
	end

	local cooldownLeft = uniformSaveLimiter:retryAfter(job)

	if uniformSaveInFlight[job] or cooldownLeft > 0 then
		xPlayer.showNotification(TranslateCap('uniform_cooldown', math.max(1, math.ceil(math.max(cooldownLeft, 0) / 1000))))
		return cb(false)
	end

	local uniform = getValidUniform(skin)
	local column = uniform and UNIFORM_COLUMNS[skin.sex] or nil

	if not column or not uniform then
		xPlayer.showNotification(TranslateCap('uniform_failed'))
		return cb(false)
	end

	local identitySex = getIdentitySex(xPlayer)
	if identitySex and identitySex ~= skin.sex then
		xPlayer.showNotification(TranslateCap('uniform_failed'))
		return cb(false)
	end

	local jobObject = Jobs[job]
	if not jobObject then
		return cb(false)
	end

	local targetGrades = {}
	local gradeLabel

	if tonumber(grade) == ALL_GRADES then
		grade = ALL_GRADES

		for _, gradeObject in pairs(jobObject.grades) do
			targetGrades[#targetGrades + 1] = gradeObject
		end

		gradeLabel = TranslateCap('uniform_all_grades')
	else
		grade = getValidJobGrade(job, grade)
		if not grade then
			return cb(false)
		end

		local gradeObject = jobObject.grades[tostring(grade)]
		targetGrades[1] = gradeObject
		gradeLabel = gradeObject.label ~= '' and gradeObject.label or jobObject.label
	end

	local changed = false

	for i = 1, #targetGrades do
		if not isSameUniform(targetGrades[i][column], uniform) then
			changed = true
			break
		end
	end

	if not changed then
		xPlayer.showNotification(TranslateCap('uniform_unchanged', gradeLabel))
		return cb(false)
	end

	local query = ('UPDATE job_grades SET %s = ? WHERE job_name = ?'):format(column)
	local parameters = {json.encode(uniform), job}

	if grade ~= ALL_GRADES then
		query = query .. ' AND grade = ?'
		parameters[#parameters + 1] = grade
	end

	uniformSaveInFlight[job] = true
	uniformSaveLimiter:consume(job)

	MySQL.update(query, parameters, function(affectedRows)
		uniformSaveInFlight[job] = nil

		if not affectedRows or affectedRows == 0 then
			uniformSaveLimiter:reset(job)
			xPlayer.showNotification(TranslateCap('uniform_failed'))
			return cb(false)
		end

		if not refreshJobOrFallback(job) then
			uniformSaveLimiter:reset(job)
			xPlayer.showNotification(TranslateCap('uniform_failed'))
			return cb(false)
		end

		xPlayer.showNotification(TranslateCap('uniform_saved', gradeLabel))
		cb(true)
	end)
end)

local getOnlinePlayers, onlinePlayers = false, nil
xLib.callback.registerCompat('esx_society:getOnlinePlayers', function(source, cb, societyName)
	local society = GetSociety(societyName)
	local xPlayer = ESX.Player(source)

	if not hasSocietyBossAccess(xPlayer, society) then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to read online players for society - ^5%s^7!'):format(source, tostring(societyName)))
		return cb({})
	end

	if getOnlinePlayers == false and onlinePlayers == nil then -- Prevent multiple xPlayer loops from running in quick succession
		getOnlinePlayers, onlinePlayers = true, {}
		
		local xPlayers = ESX.ExtendedPlayers() -- Returns all xPlayers
		for _, xPlayer in pairs(xPlayers) do
			table.insert(onlinePlayers, {
				source = xPlayer.src,
				identifier = xPlayer.getIdentifier(),
				name = xPlayer.getName(),
				job = {
					name = xPlayer.getJob().name,
					grade = xPlayer.getJob().grade,
					grade_name = xPlayer.getJob().grade_name
				}
			})
		end 
		cb(onlinePlayers)
		getOnlinePlayers = false
		Wait(1000) -- For the next second any extra requests will receive the cached list
		onlinePlayers = nil
		return
	end
	while getOnlinePlayers do Wait(0) end -- Wait for the xPlayer loop to finish
	cb(onlinePlayers)
end)


xLib.callback.registerCompat('esx_society:getVehiclesInGarage', function(source, cb, societyName)
	local society = GetSociety(societyName)
	if not society or not canAccessSocietyGarage(source, society) then
		print(('[^3WARNING^7] Attempting To get a non-existing society - %s!'):format(societyName))
		return cb({})
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		cb(garage)
	end)
end)

xLib.callback.registerCompat('esx_society:isBoss', function(source, cb, job)
	cb(isPlayerBoss(source, job))
end)

function isPlayerBoss(playerId, job)
	local xPlayer = ESX.Player(playerId)
	if not xPlayer then return false end

	local xPlayerJob = xPlayer.getJob()
	if xPlayerJob.name == job and Config.BossGrades[xPlayerJob.grade_name] then
		return true
	else
		print(('esx_society: %s attempted open a society boss menu!'):format(xPlayer.getIdentifier()))
		return false
	end
end

function WashMoneyCRON(d, h, m)
	MySQL.query('SELECT * FROM society_moneywash', function(result)
		for i=1, #result, 1 do
			local society = GetSociety(result[i].society)

			if not society then
				print(('[^3WARNING^7] Money wash pending for non-existing society - ^5%s^7!'):format(result[i].society))
			else
				local xPlayer = ESX.Player(result[i].identifier)

				-- add society money
				TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
					if not account then
						return print(('[^3WARNING^7] Society ^5%s^7 has no shared account!'):format(society.name))
					end

					MySQL.update('DELETE FROM society_moneywash WHERE id = ?', {result[i].id}, function(rowsChanged)
						if rowsChanged ~= 1 then return end

						account.addMoney(result[i].amount)

						-- send notification if player is online
						if xPlayer then
							xPlayer.showNotification(TranslateCap('you_have_laundered', ESX.Math.GroupDigits(result[i].amount)))
						end
					end)
				end)
			end
		end
	end)
end

TriggerEvent('cron:runAt', 3, 0, WashMoneyCRON)
