local A = POLICE

function POLICE.SpawnPoliceObject(model)
    local playerPed = PlayerPedId()
    local coords, forward = GetEntityCoords(playerPed), GetEntityForwardVector(playerPed)
    local objectCoords = (coords + forward * 1.0)

    ESX.Game.SpawnObject(model, objectCoords, function(obj)
        Wait(100)
        SetEntityHeading(obj, GetEntityHeading(playerPed))
        PlaceObjectOnGroundProperly(obj)
    end)
end
