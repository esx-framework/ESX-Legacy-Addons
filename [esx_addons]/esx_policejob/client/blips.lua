local A = POLICE

function createBlip(id)
    local ped = GetPlayerPed(id)
    local blip = GetBlipFromEntity(ped)
    if not DoesBlipExist(blip) then
        blip = AddBlipForEntity(ped)
        SetBlipSprite(blip, 1)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.ceil(GetEntityHeading(ped)))
        SetBlipNameToPlayerName(blip, id)
        SetBlipScale(blip, 0.85)
        SetBlipAsShortRange(blip, true)
        table.insert(A.blipsCops, blip)
    end
end

CreateThread(function()
    for _, v in pairs(Config.PoliceStations) do
        local blip = AddBlipForCoord(v.Blip.Coords)
        SetBlipSprite (blip, v.Blip.Sprite)
        SetBlipDisplay(blip, v.Blip.Display)
        SetBlipScale  (blip, v.Blip.Scale)
        SetBlipColour (blip, v.Blip.Colour)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(TranslateCap('map_blip'))
        EndTextCommandSetBlipName(blip)
    end
end)
