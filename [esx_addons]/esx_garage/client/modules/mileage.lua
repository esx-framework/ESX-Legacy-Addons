local ONE_MILE_IN_METERS <const> = 1609

Mileage = {}

function Mileage.StartLoop()
    if not PLAYER_VEHICLE then
        return
    end

    local miles = Entity(PLAYER_VEHICLE).state.mileage or 0
    local last_pos = GetEntityCoords(PLAYER_VEHICLE)

    local player_ped = PlayerPedId()

    while true do
        if not PLAYER_VEHICLE then
            break
        end

        local new_pos = GetEntityCoords(PLAYER_VEHICLE)

        if GetPedInVehicleSeat(PLAYER_VEHICLE, -1) == player_ped and GetIsVehicleEngineRunning(PLAYER_VEHICLE) then
            local dist = #(new_pos - last_pos)

            local miles_done = dist / ONE_MILE_IN_METERS
            miles += miles_done

            miles = ESX.Math.Round(miles, 4)

            Entity(PLAYER_VEHICLE).state:set('mileage', miles, true)
        end

        last_pos = new_pos

        Citizen.Wait(1000)
    end
end
