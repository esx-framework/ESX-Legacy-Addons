Shared = Shared or {}
Shared.Class = Shared.Class or {}

---@class SerializedTime
---@field hours integer
---@field minutes integer
---@field seconds integer

---@class Time:SerializedTime
---@field new fun(self: Time, SerializedTime:SerializedTime): Time
---@field add fun(self: Time, SerializedTime:SerializedTime)
---@field serialize fun(self: Time): SerializedTime
Shared.Class.Time = {}

---@param SerializedTime SerializedTime
---@return Time
function Shared.Class.Time:new(SerializedTime)
    local time = {}
    setmetatable(time, self)
    self.__index = self

    time.hours = SerializedTime.hours
    time.minutes = SerializedTime.minutes
    time.seconds = SerializedTime.seconds

    return time
end

function Shared.Class.Time:add(SerializedTime)
    self.seconds += SerializedTime.seconds
    self.minutes += SerializedTime.minutes + math.floor(self.seconds / 60)
    self.hours += (SerializedTime.hours + math.floor(self.minutes / 60))

    self.seconds = self.seconds % 60
    self.minutes = self.minutes % 60
    self.hours = self.hours % 24
end

function Shared.Class.Time:serialize()
    return {
        hours = self.hours,
        minutes = self.minutes,
        seconds = self.seconds
    }
end
