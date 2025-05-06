HUD.VersionCheckURL = "https://api.github.com/repos/esx-framework/esx-hud/releases/latest"

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
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)
        local latestVersion
        if not currentVersion then
            return
        end

        if err ~= 200 then
            HUD:ErrorHandle(Translate("errorGetCurrentVersion"))
            return
        end
        if response then
            response = json.decode(response)
            if not response.tag_name then
                return
            end

            latestVersion = response.tag_name:match("%d%.%d+%.%d+")
            currentVersion = currentVersion:match("%d%.%d+%.%d+")

            if not latestVersion then
                return
            end

            if currentVersion == latestVersion then
                HUD:InfoHandle(Translate("latestVersion"), "green")
                return
            end

            local currentVersionSplitted = { string.strsplit(".", currentVersion) }
            local latestVersionSplitted = { string.strsplit(".", latestVersion) }

            HUD:InfoHandle(Translate("currentVersion") .. latestVersion, "green")
            HUD:InfoHandle(Translate("yourVersion") .. currentVersion, "blue")

            for i = 1, #currentVersionSplitted do
                local current, latest = tonumber(currentVersionSplitted[i]), tonumber(latestVersionSplitted[i])
                if current ~= latest then
                    if not current or not latest then
                        return
                    end
                    if current < latest then
                        HUD:InfoHandle(Translate("needUpdateResource"), "red")
                    else
                        break
                    end
                end
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
