local Strings = {
	-- Notifications
	['shop_loading'] = '~r~Shop is still loading, please wait...',
	['purchase_success'] = 'Purchase successful! Total: $%s',
	['purchase_success_tax_exempt'] = 'Purchase successful! Total: $%s (Tax exempt)',
	['not_enough_money'] = 'Not enough money! Missing $%s',
	['inventory_full'] = 'Cannot carry items - inventory full!',
	['transaction_error'] = 'Transaction error - contact an administrator',
	['invalid_shop'] = 'Invalid shop',
	['invalid_items'] = 'Invalid items',
	['invalid_payment'] = 'Invalid payment method',
	['price_mismatch'] = 'Price mismatch',
	['rate_limited'] = 'Please wait before making another purchase',
	['no_shop_selected'] = 'No shop selected',
	['shop_already_open'] = 'Shop already open',
	['nui_not_ready'] = '~r~Shop is still loading, please wait...',

	-- Tax
	['tax_exempt_msg'] = 'Thanks for your service!',
	['tax_collection_error'] = 'Tax society account %s not found - tax amount $%s was not collected',

	-- UI
	['press_e_shop'] = 'Press [~b~E~s~] to access the ~g~%s~s~.',

	-- Warnings / Logs
	['invalid_player'] = '[^3WARNING^7] Invalid player ^5%s^7 attempted purchase',
	['invalid_zone'] = '[^3WARNING^7] Player ^5%s^7 attempted purchase from invalid zone ^5%s^7',
	['invalid_payment_method'] = '[^3WARNING^7] Player ^5%s^7 attempted invalid payment method ^5%s^7',
	['negative_quantity'] = '[^3WARNING^7] Player ^5%s^7 attempted negative/zero quantity exploit',
	['excessive_quantity'] = '[^3WARNING^7] Player ^5%s^7 attempted to buy excessive quantity ^5%s^7 (max: ^5%s^7)',
	['invalid_price'] = '[^1ERROR^7] Invalid price ^5%s^7 for item ^5%s^7 in zone ^5%s^7 - check Config.lua',
	['price_manipulation'] = '[^3WARNING^7] Player ^5%s^7 attempted price manipulation for ^5%s^7 (server: ^5%s^7, client: ^5%s^7)',
	['total_manipulation'] = '[^3WARNING^7] Player ^5%s^7 attempted total manipulation (server: ^5%s^7, client: ^5%s^7)',
	['rate_limited_log'] = '[^3WARNING^7] Player ^5%s^7 is rate limited (cooldown: ^5%sms^7)',
	['item_add_failed'] = '[^1ERROR^7] Failed to add item ^5%s^7 to player ^5%s^7 inventory',
	['critical_transaction'] = '[^1CRITICAL^7] Failed to add items after money deduction for player ^5%s^7',
	['tax_callback_timeout'] = '[^3WARNING^7] Tax rate callback timeout - using default rate',
}

---Translates a string key with optional formatting
---@param key string
---@param ... any
---@return string
function _U(key, ...)
	local str = Strings[key] or key
	if ... then
		return str:format(...)
	end
	return str
end
