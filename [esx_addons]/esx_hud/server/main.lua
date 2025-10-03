HUD.VersionCheckURL = "https://raw.githubusercontent.com/esx-framework/ESX-Legacy-Addons/refs/heads/main/versions.json"

function HUD:ErrorHandle(msg)
    print(("[^1ERROR^7] ^3esx_hud^7: %s"):format(msg))
end

function HUD:InfoHandle(msg, color)
    if color == "green" then
        color = 2
    elseif color == "red" then
        color = 1
    elseif color == "blue" then
        color = 4
    else
        color = 3
    end
    print(("[^9INFO^7] ^3esx_hud^7: ^" .. color .. "%s^7"):format(msg))
end

VERSION = {
    Check = function(err, response, headers)
        --Credit: OX_lib version checker by Linden
        local resourceName = GetCurrentResourceName()
        local currentVersion = GetResourceMetadata(resourceName, "version", 0)
        if not currentVersion then return end

        HUD:InfoHandle(("Checking version from %s"):format(HUD.VersionCheckURL), "blue")

        if err ~= 200 or not response then
            HUD:ErrorHandle(Translate("errorGetCurrentVersion"))
            return
        end

        local ok, parsed = pcall(json.decode, response)
        if not ok or type(parsed) ~= "table" then
            HUD:ErrorHandle("Failed to parse the remote versions.json")
            return
        end

        local remoteVersion = parsed[resourceName] or parsed["esx_hud"]
        if not remoteVersion then
            HUD:ErrorHandle(("versions.json does not contain an entry for '%s'"):format(resourceName))
            return
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

        local latestVersion = normalizeSemver(remoteVersion)
        currentVersion = normalizeSemver(currentVersion)

        if not latestVersion or not currentVersion then
            HUD:ErrorHandle("Invalid local or remote version for comparison")
            return
        end

        if currentVersion == latestVersion then
            HUD:InfoHandle(Translate("latestVersion"), "green")
            HUD:InfoHandle(("Up to date version (%s)"):format(currentVersion), "green")
            return
        end

        local currentVersionSplitted = { string.strsplit(".", currentVersion) }
        local latestVersionSplitted = { string.strsplit(".", latestVersion) }

        HUD:InfoHandle(Translate("currentVersion") .. latestVersion, "green")
        HUD:InfoHandle(Translate("yourVersion") .. currentVersion, "blue")
        HUD:InfoHandle(("Update available: remote %s > local %s"):format(latestVersion, currentVersion), "red")

        for i = 1, #currentVersionSplitted do
            local current, latest = tonumber(currentVersionSplitted[i]), tonumber(latestVersionSplitted[i])
            if current ~= latest then
                if not current or not latest then
                    return
                end
                if current < latest then
                    HUD:InfoHandle(Translate("needUpdateResource"), "red")
                end
                break
            end
        end
    end,

    RunVersionChecker = function()
        CreateThread(function()
            PerformHttpRequest(HUD.VersionCheckURL, VERSION.Check, "GET")
        end)
    end,
}

RegisterNetEvent("esx_hud:ErrorHandle", function(msg)
    HUD:ErrorHandle(msg)
end)

AddEventHandler("onResourceStart", function(resourceName)
    local currentName = GetCurrentResourceName()
    if resourceName ~= currentName then
        return
    end
    local built = LoadResourceFile(currentName, "./web/dist/index.html")

    Wait(100)

    --Run version checker
    VERSION:RunVersionChecker()

    if not built then
        CreateThread(function()
            while true do
                HUD:ErrorHandle(Translate("resource_not_built"))
                Wait(10000)
            end
        end)
    end
end)
