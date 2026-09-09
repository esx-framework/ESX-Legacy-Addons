-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---Handles purchase requests from clients
xLib.callback.registerCompat('esx_shops:purchaseItems', function(source, cb, purchaseData, zone)
	ProcessPurchase(source, purchaseData, zone, cb)
end)
