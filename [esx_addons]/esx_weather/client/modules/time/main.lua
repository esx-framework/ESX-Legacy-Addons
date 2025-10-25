Modules = Modules or {}
Modules.Time = Modules.Time or {}

Modules.Time.currentTime = false ---@type Time|false
Modules.Time.syncedAt = false ---@type integer|false
Modules.Time.currentZone = false ---@type Zone|false
Modules.Time.isSyncEnabled = true

local MS_PER_SECOND <const> = 1000

---@param currentTime SerializedTime
function Modules.Time.set(currentTime)
    Modules.Time.currentTime = currentTime
    Modules.Time.syncedAt = GetGameTimer()
end

function Modules.Time.tick()
    if (not Modules.Time.isSyncEnabled) then
        return
    end

    if (not Modules.Time.currentTime or not Modules.Time.syncedAt) then
        return
    end
    local closestZone = Modules.Zone.getClosest()

    if (Modules.Time.currentZone == closestZone) then
        return
    end

    Modules.Time.currentZone = closestZone
    local zoneHoursOffset = Config.Time.Zones[Modules.Time.currentZone] or 0

    local elapsedMs = GetGameTimer() - Modules.Time.syncedAt
    local elapsedSeconds = math.floor(elapsedMs / MS_PER_SECOND)

    local currentTime = Shared.Class.Time:new(Modules.Time.currentTime):add({
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

---@param toggle boolean
function Modules.Time.toggleSync(toggle)
    assert(type(toggle) == "boolean", "toggle must be a boolean")

    Modules.Time.isSyncEnabled = toggle
end
