DMV = DMV or {}

DMV.VersionCheckBaseURL = "https://raw.githubusercontent.com/esx-framework/ESX-Legacy-Addons/main/%5Besx_addons%5D/"

function DMV:ErrorHandle(msg)
    local resourceName = GetCurrentResourceName()
    print(("[^1ERROR^7] ^3%s^7: %s"):format(resourceName, msg))
end

function DMV:InfoHandle(msg, color)
    local resourceName = GetCurrentResourceName()
    local c = ({green=2, red=1, blue=4})[color] or 3
    print(("[^9INFO^7] ^3%s^7: ^" .. c .. "%s^7"):format(resourceName, msg))
end

local function normalizeSemver(v)
    if type(v) ~= "string" then return nil end
    local three = v:match("%d+%.%d+%.%d+")
    if three then return three end
    local two = v:match("^%d+%.%d+$")
    if two then return (two .. ".0") end
    local one = v:match("^%d+$")
    if one then return (one .. ".0.0") end
    return nil
end

VERSION = {
    Check = function(err, response, headers)
        local resourceName = GetCurrentResourceName()
        local currentVersion = GetResourceMetadata(resourceName, "version", 0)
        if not currentVersion then return end

        local manifestURL = DMV.VersionCheckBaseURL .. resourceName .. "/fxmanifest.lua"
        DMV:InfoHandle(("Checking manifest from %s"):format(manifestURL), "blue")

        if err ~= 200 or not response then
            DMV:ErrorHandle(Translate("errorGetCurrentVersion"))
            return
        end

        local remoteVersion = response:match("version%s+'([%d%.]+)'")
        if not remoteVersion then
            DMV:ErrorHandle(Translate("errorGetRemoteVersion"))
            return
        end

        local latestVersion = normalizeSemver(remoteVersion)
        currentVersion = normalizeSemver(currentVersion)

        if not latestVersion or not currentVersion then
            DMV:ErrorHandle(Translate("invalidVersion"))
            return
        end

        if currentVersion == latestVersion then
            DMV:InfoHandle(Translate("latestVersion"), "green")
            DMV:InfoHandle(("Up to date version (%s)"):format(currentVersion), "green")
            return
        end

        local currentVersionSplitted = { string.strsplit(".", currentVersion) }
        local latestVersionSplitted = { string.strsplit(".", latestVersion) }

        DMV:InfoHandle(Translate("currentVersion") .. latestVersion, "green")
        DMV:InfoHandle(Translate("yourVersion") .. currentVersion, "blue")
        DMV:InfoHandle(("Update available: remote %s > local %s"):format(latestVersion, currentVersion), "red")

        for i = 1, #currentVersionSplitted do
            local current, latest = tonumber(currentVersionSplitted[i]), tonumber(latestVersionSplitted[i])
            if current ~= latest then
                if not current or not latest then return end
                if current < latest then
                    DMV:InfoHandle(Translate("needUpdateResource"), "red")
                end
                break
            end
        end
    end,

    RunVersionChecker = function()
        CreateThread(function()
            local resourceName = GetCurrentResourceName()
            local manifestURL = DMV.VersionCheckBaseURL .. resourceName .. "/fxmanifest.lua"
            PerformHttpRequest(manifestURL, VERSION.Check, "GET")
        end)
    end,
}

AddEventHandler("onResourceStart", function(resourceName)
    local currentName = GetCurrentResourceName()
    if resourceName ~= currentName then return end

    Wait(100)
    VERSION:RunVersionChecker()
end)