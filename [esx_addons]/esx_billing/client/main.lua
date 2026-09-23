-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local isDead = false

local function showBillsMenu()
	xLib.callback('esx_billing:getBills', false, function(bills)
		if #bills <= 0 then return ESX.ShowNotification(TranslateCap('no_invoices')) end

		local elements = {
			{ unselectable = true, icon = 'fas fa-scroll', title = TranslateCap('invoices') }
		}

		for _, v in ipairs(bills) do
			elements[#elements + 1] = {
				icon = 'fas fa-scroll',
				title = ('%s - <span style="color:red;">%s</span>'):format(v.label,
					TranslateCap('invoices_item', ESX.Math.GroupDigits(v.amount))),
				billId = v.id
			}
		end

		ESX.OpenContext('right', elements, function(menu, element)
			local billId = element.billId

			xLib.callback('esx_billing:payBill', false, function(resp)
				showBillsMenu()

				if not resp then return end
				TriggerEvent('esx_billing:paidBill', billId)
			end, billId)
		end)
	end)
end

RegisterCommand('showbills', function()
	if not isDead then
		showBillsMenu()
	end
end, false)

RegisterKeyMapping('showbills', TranslateCap('keymap_showbills'), 'keyboard', 'F7')

RegisterNetEvent('esx_billing:confirmHighBill', function(token, label, amount, senderName)
	local elements = {
		{ unselectable = true, icon = 'fas fa-scroll', title = ('%s - %s'):format(label, ESX.Math.GroupDigits(amount)) },
		{ icon = 'fas fa-check', title = 'Accept invoice', value = true },
		{ icon = 'fas fa-times', title = 'Decline invoice', value = false }
	}

	ESX.ShowNotification(('High invoice from %s requires confirmation'):format(senderName or 'unknown'))

	ESX.OpenContext('right', elements, function(menu, element)
		if element.value == nil then return end

		xLib.callback('esx_billing:respondHighBill', false, function() end, token, element.value == true)
		ESX.CloseContext()
	end, function()
		xLib.callback('esx_billing:respondHighBill', false, function() end, token, false)
	end)
end)

AddEventHandler('esx:onPlayerDeath', function() isDead = true end)
AddEventHandler('esx:onPlayerSpawn', function() isDead = false end)
