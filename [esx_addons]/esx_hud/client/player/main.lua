local bool, ammoInClip = false, 0
local WeaponList = {}
function HUD:GetJobLabel()
    if not ESX.PlayerData.job then
        return
    end
    if ESX.PlayerData.job.name == "unemployed" then
        return ESX.PlayerData.job.label
    end

    return string.format("%s - %s", ESX.PlayerData.job.label, ESX.PlayerData.job.grade_label)
end

function HUD:GetLocation()
    local PPos = GetEntityCoords(ESX.PlayerData.ped)
    local streetHash = GetStreetNameAtCoord(PPos.x, PPos.y, PPos.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    return streetName
end

function HUD:UpdateAccounts(accounts)
    if not Config.Disable.Money then
        if accounts == nil then
            return
        end
        for _, data in pairs(accounts) do
            if data.name == "bank" then
                self.Data.Money.bank = data.money
            elseif data.name == "money" then
                self.Data.Money.cash = data.money
            end
        end
    end
end

function HUD:GetWeapons()
    WeaponList = ESX.GetWeaponList(true)
end

function HUD:SlowThick()
    CreateThread(function()
        while not ESX.PlayerLoaded do
            Wait(200)
        end
        while ESX.PlayerLoaded do
            self.Data.Position = GetEntityCoords(ESX.PlayerData.ped)

            if not Config.Disable.Position then
                self.Data.Location = self:GetLocation()
            end

            if not Config.Disable.Weapon then
                self.Data.Weapon.Active, self.Data.Weapon.CurrentWeapon = GetCurrentPedWeapon(ESX.PlayerData.ped, false)
                if self.Data.Weapon.CurrentWeapon == 0 then
                    self.Data.Weapon.Active = false
                end
                if self.Data.Weapon.Active and WeaponList[self.Data.Weapon.CurrentWeapon] then
                    self.Data.Weapon.MaxAmmo = (GetAmmoInPedWeapon(ESX.PlayerData.ped, self.Data.Weapon.CurrentWeapon) - ammoInClip)
                    self.Data.Weapon.Name = WeaponList[self.Data.Weapon.CurrentWeapon].label and WeaponList[self.Data.Weapon.CurrentWeapon].label or false
                    self.Data.Weapon.isWeaponMelee = not WeaponList[self.Data.Weapon.CurrentWeapon].ammo
                    self.Data.Weapon.Image = string.gsub(WeaponList[self.Data.Weapon.CurrentWeapon].name, "WEAPON_", "")
                    self.Data.Weapon.Image = string.lower(self.Data.Weapon.Image)
                end

                --here we handle it when we find a hash that is not in the weapon list so we don't show the weapon data on the hud
                if self.Data.Weapon.Active then
                    self.Data.Weapon.Active = self.Data.Weapon.CurrentWeapon ~= 0 and self.Data.Weapon.Name and self.Data.Weapon.Image
                end
            end

            Wait(1000)
        end
    end)
end

function HUD:FastThick()
    CreateThread(function()
        while not ESX.PlayerLoaded do
            Wait(200)
        end

        local srvLogo = Config.Default.ServerLogo
        while ESX.PlayerLoaded do
            if not Config.Disable.Voice then
                self.Data.isTalking = NetworkIsPlayerTalking(ESX.playerId)
            end

            if self.Data.Weapon.Active then
                bool, ammoInClip = GetAmmoInClip(ESX.PlayerData.ped, self.Data.Weapon.CurrentWeapon)
                self.Data.Weapon.CurrentAmmo = ammoInClip
            end

            local values = {
                playerId = ESX.serverId,
                onlinePlayers = GlobalState["playerCount"],
                serverLogo = srvLogo,
                moneys = { bank = self.Data.Money.bank or 0, money = self.Data.Money.cash or 0 },
                weaponData = {
                    use = self.Data.Weapon.Active,
                    image = self.Data.Weapon.Image or false,
                    name = self.Data.Weapon.Name or false,
                    isWeaponMelee = self.Data.Weapon.isWeaponMelee,
                    currentAmmo = self.Data.Weapon.CurrentAmmo or 0,
                    maxAmmo = self.Data.Weapon.MaxAmmo or 0,
                },
                streetName = self.Data.Location or "Unknown street",
                voice = {
                    mic = self.Data.isTalking or false,
                    radio = self.Data.isTalkingOnRadio,
                    range = self.Data.VoiceRange,
                },
                job = HUD:GetJobLabel(),
            }

            SendNUIMessage({ type = "HUD_DATA", value = values })
            Wait(500)
        end
    end)
end

-- Handlers
-- On script start
AddEventHandler("onResourceStart", function(resource)
    if GetCurrentResourceName() ~= resource then
        return
    end
    Wait(1000)
    if not Config.Disable.Weapon then
        HUD:GetWeapons()
    end
end)

-- On player loaded
ESX.SecureNetEvent("esx:playerLoaded", function(xPlayer)
    if not Config.Disable.Weapon then
        HUD:GetWeapons()
    end
    HUD:GetJobLabel(xPlayer.job)
end)

AddEventHandler("esx:pauseMenuActive", function(state)
    if HUD.Data.hudHidden then
        return
    end
    HUD:Toggle(not state)
end)

-- job handler
RegisterNetEvent("esx:setJob")
AddEventHandler("esx:setJob", function(job)
    ESX.PlayerData.job = job
end)

--Cash and Bank handler
if not Config.Disable.Money then
    RegisterNetEvent("esx:setAccountMoney", function(account)
        if account.name == "money" then
            HUD.Data.Money.cash = account.money
        elseif account.name == "bank" then
            HUD.Data.Money.bank = account.money
        end
    end)
end
