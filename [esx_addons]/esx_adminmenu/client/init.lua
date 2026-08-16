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

ESX.TriggerServerCallback('esx-adminmenu:server:getInitData', function(data)
    if not data or data.err then
        if data.err and Config.Debug then
            print(data.err)
        end
        return
    end
    data.translations = activeTranslations()
    SendNUIMessage({
        action = 'initResource',
        data = data
    })
end)
