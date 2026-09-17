-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

JobListingUI = {}

local uiOpen = false

---Gets ESX theme colors from convars
---@return table
function JobListingUI.GetESXThemeColors()
	local defaults = {
		primaryColor = '#FB9B04',
		secondaryColor = '#252525',
		backgroundColor = '#161616',
		accentColor = '#383838'
	}

	if type(xLib) == 'table' and type(xLib.colors) == 'table' and type(xLib.colors.getESXTheme) == 'function' then
		return xLib.colors.getESXTheme(defaults)
	end

	return defaults
end

---Builds the localized UI strings payload for the NUI
---@return table
function JobListingUI.GetNuiLocalePayload()
	return {
		language = Config.Locale or 'en',
		title = TranslateCap('ui_title'),
		subtitle = TranslateCap('ui_subtitle'),
		search = TranslateCap('ui_search'),
		searchPlaceholder = TranslateCap('ui_search_placeholder'),
		close = TranslateCap('ui_close'),
		currentTag = TranslateCap('ui_current_tag'),
		salary = TranslateCap('ui_salary'),
		noJobs = TranslateCap('ui_no_jobs'),
		noResults = TranslateCap('ui_no_results'),
		confirmTitle = TranslateCap('ui_confirm_title'),
		confirmYes = TranslateCap('ui_confirm_yes'),
		confirmNo = TranslateCap('ui_confirm_no'),
		applied = TranslateCap('ui_applied'),
		requestFailed = TranslateCap('ui_request_failed')
	}
end

---Checks if the joblisting NUI is open
---@return boolean
function JobListingUI.IsOpen()
	return uiOpen
end

---Opens the joblisting NUI
function JobListingUI.Open()
	if uiOpen then
		return
	end

	xLib.callback('esx_joblisting:getJobsList', false, function(jobs)
		if uiOpen then
			return
		end

		uiOpen = true
		ESX.HideUI()

		local job = ESX.PlayerData.job
		local payload = {
			action = 'open',
			jobs = jobs,
			currentJob = job and { name = job.name, label = job.label },
			locale = JobListingUI.GetNuiLocalePayload(),
			theme = JobListingUI.GetESXThemeColors()
		}

		xLib.nui.focus(true, true)
		xLib.nui.send(payload)
	end)
end

---Closes the joblisting NUI
function JobListingUI.Close()
	if not uiOpen then
		return
	end

	uiOpen = false
	xLib.nui.close({ action = 'close' })
end

-- NUI Ready callback — returns theme colors from convars
xLib.nui.register('ready', function()
	return { theme = JobListingUI.GetESXThemeColors() }
end)

-- NUI Close callback
xLib.nui.register('close', function()
	JobListingUI.Close()
	return xLib.nui.ok()
end)

-- NUI Apply callback — validates and sets the player job
xLib.nui.register('apply', function(data, reply)
	if type(data) ~= 'table' or type(data.job) ~= 'string' then
		reply(xLib.nui.fail('Invalid job data'))
		return
	end

	local job = data.job

	xLib.callback('esx_joblisting:applyJob', false, function(result)
		result = result or {}

		if result.success then
			local label = result.label or job
			ESX.ShowNotification(TranslateCap('new_job', label), "success")
			reply(xLib.nui.ok({ label = label }))
			return
		end

		reply(xLib.nui.fail(result.reason or 'unknown'))
	end, job)

	return xLib.nui.defer
end)

-- Close the NUI if the resource is stopped
AddEventHandler('onClientResourceStop', function(resource)
	if resource == GetCurrentResourceName() and uiOpen then
		JobListingUI.Close()
	end
end)