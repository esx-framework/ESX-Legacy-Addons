NUI = {}

NUI.OpenGarage = function()
    local payload = Actions.GaragePayload()

    if not payload then
        return
    end

    SendNUIMessage({
        type = 'openGarage',
        payload = payload
    })

    SetNuiFocus(true, true)
end

---@param body { vehicleId: string, isFavorite: boolean }
---@param cb function
RegisterNUICallback('garage:toggleFavorite', function(body, cb)
    cb(Actions.ToggleFavorite(body))
end)

---@param body { vehicleId: string, newName: string }
---@param cb function
RegisterNUICallback('garage:renameVehicle', function(body, cb)
    cb(Actions.RenameVehicle(body))
end)
---@param body { vehicleId: string, targetId: string}
---@param cb function
RegisterNuiCallback('garage:transferVehicle', function(body, cb)
    cb(Actions.TransferVehicle(body))
end)

---@param body { vehicleId: string }
---@param cb function
RegisterNuiCallback('garage:retrieveVehicle', function(body, cb)
    cb(Actions.RetrieveVehicle(body))
end)

---@param body { vehicleId: string, targetId: string}
---@param cb function
RegisterNuiCallback('garage:addSecondOwner', function(body, cb)
    cb(Actions.AddSecondOwner(body))
end)

---@param body { vehicleId: string, targetId: string}
---@param cb function
RegisterNuiCallback('garage:removeSecondOwner', function(body, cb)
    cb(Actions.RemoveSecondOwner(body))
end)

---@param body { type: 'impound' | 'find', vehicleId: string }
---@param cb function
RegisterNuiCallback('garage:impoundVehicle', function(body, cb)
    cb(Actions.ImpoundVehicle(body))
end)

---@param cb function
RegisterNUICallback('garage:closeUI', function(_, cb)
    SetNuiFocus(false, false)

    SendNUIMessage({
        type = 'closeGarage',
        payload = {}
    })

    cb({ success = true })
end)

---@param body { hasFocus: boolean, hasCursor: boolean }
---@param cb function
RegisterNUICallback('SetNuiFocus', function(body, cb)
    SetNuiFocus(body.hasFocus, body.hasCursor)

    cb({
        success = true
    })
end)
