ESX.RegisterServerCallback('esx_garages/getOwnedVehicles', function(playerId, cb)
	local xPlayer = ESX.Player(playerId)

	if not xPlayer then
		return
	end

	local isAllowed = true

	if not isAllowed then
		return cb('not-allowed')
	end

	---@type GarageVehicleDB[]
	local owned_vehicles = MySQL.query.await('SELECT * FROM `owned_vehicles` WHERE owner = ?',
		{ xPlayer.getIdentifier() })

	if not owned_vehicles then
		return cb('no-vehicles')
	end

	cb(owned_vehicles)
end)
