-- Translations are already shipped with the resource, so resolve them here
-- instead of paying for them in the init payload. The NUI keeps a full English
-- set and merges these over it, so any missing key falls back on its own.
local function activeTranslations()
    local locale = Locales[Config.Locale]
    if type(locale) ~= 'table' then
        locale = Locales['en']
    end
    return locale or {}
end

local initAttempts = 0
local initRequestPending = false
local maxInitAttempts = 60

local function hasEntries(value)
    return type(value) == 'table' and next(value) ~= nil
end

local function requestInitData()
    if initRequestPending then
        return
    end

    initRequestPending = true
    initAttempts = initAttempts + 1

    xLib.callback('esx-adminmenu:server:getInitData', false, function(data)
        initRequestPending = false

        if not data or data.err then
            if data and data.err and Config.Debug then
                print(data.err)
            end
            return
        end

        data.translations = activeTranslations()
        xLib.nui.send({
            action = 'initResource',
            data = data
        })

        if not hasEntries(data.impounds) and initAttempts < maxInitAttempts then
            SetTimeout(1000, requestInitData)
        end
    end)
end

function RefreshAdminInitData()
    initAttempts = 0
    requestInitData()
end

requestInitData()
