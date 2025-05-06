if not Config.Disable.Vehicle then
    if GetResourceState("LegacyFuel") == "started" then
        function HUD:FuelExport()
            return ESX.Math.Round(exports["LegacyFuel"]:GetFuel(HUD.Data.Vehicle), 2)
        end
    else
        function HUD:FuelExport()
            return ESX.Math.Round(GetVehicleFuelLevel(HUD.Data.Vehicle), 2)
        end
    end
end
