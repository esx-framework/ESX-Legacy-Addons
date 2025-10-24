Modules = Modules or {}
Modules.Time = {}

---@param src integer?
function Modules.Time.broadcast(src)
    TriggerClientEvent("esx_weather:client:time:setTime", (src or -1), Modules.Time.get():serialize())
end

---@return Time
function Modules.Time.get()
    local t = os.date("*t")

    local SerializedTime = {
        hours = tonumber(t.hour) or 0,
        minutes = tonumber(t.min) or 0,
        seconds = tonumber(t.sec) or 0
    } --[[@as SerializedTime]]

    return Shared.Class.Time:new(SerializedTime)
end
