SB = {
	cacheVeh = nil,
	isRagdoll = false,
	carArray = {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 17, 18, 19, 20},
	seatbelt = false,
	vehSpeed = 0.0,
	previousVelocity = vector3(0,0,0),
	Reset = function(self)
		self.cacheVeh = nil
		self.carArray = {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 17, 18, 19, 20}
		self.seatbelt = false
		self.vehSpeed = 0.0
		self.isRagdoll = false
	end,
	EjectSeat = function(self)
		local position = GetEntityCoords(Utils.ped)
		SetEntityCoords(Utils.ped, position.x, position.y, position.z - 0.47, true, true, true, false)
        SetEntityVelocity(Utils.ped, self.previousVelocity.x, self.previousVelocity.y, self.previousVelocity.z)
		self:SetRagdoll()
		Citizen.SetTimeout((Config.Seatbelt.RagdollTime or 1) * 1000, function()
			self:Reset()
		end)
	end,
	Logic = function(self)
		local prevSpeed = self.vehSpeed
		self.vehSpeed = GetEntitySpeed(self.cacheVeh)
		SetPedConfigFlag(Utils.ped, 32, true)

		if self.seatbelt then
			return DisableControlAction(0, 75, false)
		end

		local isVehMovingFwd = GetEntitySpeedVector(self.cacheVeh, true).y > 1.0
		local vehAcceleration = (prevSpeed - self.vehSpeed) / GetFrameTime()
		local speedIsBiggerThanConfigMPH = prevSpeed > ((Config.Seatbelt.EjectCheckSpeed or 45)/2.237)
		local reallyFast = vehAcceleration > (100*9.81)

		if (isVehMovingFwd and speedIsBiggerThanConfigMPH and reallyFast) then
			self:EjectSeat()
		else
			self.previousVelocity = GetEntityVelocity(self.cacheVeh)
		end
	end,
	Thread = function(self)
		CreateThread(function ()
			while true do
				if not Utils.vehicle then break end
				if not self.cacheVeh or self.cacheVeh ~= Utils.vehicle then
					local vehClass = GetVehicleClass(Utils.vehicle)
					for i = 1, #self.carArray do
						if self.carArray[i] == vehClass then
							self.cacheVeh = Utils.vehicle
							break
						end
					end
				end
				self:Logic()
				Wait(200)
			end
		end)
	end,
	DisableExit = function(self)
		CreateThread(function ()
			while self.seatbelt do
				DisableControlAction(0, 75, true)
				Wait(0)
			end
		end)
	end,
	SetState = function(self, state)
		if not Config.Seatbelt.Enable then return end
		Utils:SetHudState(state, true)
		if not state then
			self:Reset()
			return
		end
		self:DisableExit()
	end,
	SetRagdoll = function(self)
		self.isRagdoll = true
		CreateThread(function()
			while self.isRagdoll do
				Wait(0)
				SetPedToRagdoll(Utils.ped, 1000, 1000, 0, false, false, false)
			end
		end)
	end
}

exports('isSeatbeltOn', function()
	return SB.seatbelt
end)