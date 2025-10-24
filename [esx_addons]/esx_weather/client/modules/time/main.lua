Modules = Modules or {}
Modules.Time = Modules.Time or {}

Modules.Time.currentTime = false ---@type Time|false
Modules.Time.syncedAt = false ---@type integer|false
Modules.Time.currentZone = false ---@type string|false

local MS_PER_SECOND <const> = 1000

---@param currentTime SerializedTime
function Modules.Time.set(currentTime)
    Modules.Time.currentTime = currentTime
    Modules.Time.syncedAt = GetGameTimer()
end

Citizen.CreateThread(function()
    while (true) do
        if (Modules.Time.currentTime and Modules.Time.syncedAt) then
            local closestZone = Modules.Zone.getClosest()

            if (not Modules.Time.currentZone or Modules.Time.currentZone ~= closestZone) then
                Modules.Time.currentZone = closestZone
                local zoneHoursOffset = Config.Time.Zones[Modules.Time.currentZone] or 0

                local elapsedMs = GetGameTimer() - Modules.Time.syncedAt
                local elapsedSeconds = math.floor(elapsedMs / MS_PER_SECOND)

                local currentTime = Shared.Class.Time:new(Modules.Time.currentTime)
                currentTime:add({
                    hours = zoneHoursOffset,
                    minutes = 0,
                    seconds = elapsedSeconds
                })

                Shared.Modules.Debug.print(("Setting time for zone %s (offset %dh): %02d:%02d:%02d"):format(
                    Modules.Time.currentZone,
                    zoneHoursOffset,
                    currentTime.hours,
                    currentTime.minutes,
                    currentTime.seconds
                ))

                AdvanceClockTimeTo(currentTime.hours, currentTime.minutes, currentTime.seconds)
            end
        end

        Citizen.Wait(1000)
    end
end)
