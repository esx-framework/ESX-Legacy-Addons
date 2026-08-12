---@param xPlayer table ESX player object
---@return boolean isExempt
function IsJobTaxExempt(xPlayer)
	if not Config.EnableTaxExemptions then
		return false
	end

	local playerJob = xPlayer.getJob().name
	local exemptJobsCount = #Config.TaxExemptJobs

	for i = 1, exemptJobsCount do
		if Config.TaxExemptJobs[i] == playerJob then
			return true
		end
	end

	return false
end

---Calculates actual payment and tax for a purchase
---@param xPlayer table ESX player object
---@param grossTotal number Gross total from server calculation
---@return number actualTotal Net amount player pays
---@return number actualTax Tax amount collected
function CalculateTax(xPlayer, grossTotal)
	local actualTax = 0
	local actualTotal = grossTotal

	if IsJobTaxExempt(xPlayer) then
		actualTotal = grossTotal / (1 + Config.TaxRate)
	else
		actualTax = grossTotal - (grossTotal / (1 + Config.TaxRate))
	end

	return actualTotal, actualTax
end

---Deposits tax amount to society account
---@param taxAmount number Tax amount to deposit
function DepositTaxToSociety(taxAmount)
	if not Config.EnableTaxCollection then return end
	if taxAmount <= 0 then return end

	TriggerEvent('esx_addonaccount:getSharedAccount', Config.TaxSocietyAccount, function(account)
		if account then
			account.addMoney(taxAmount)
		else
			DebugPrint(_U('tax_collection_error', Config.TaxSocietyAccount, ESX.Math.Round(taxAmount)))
		end
	end)
end

ESX.RegisterServerCallback('esx_shops:getTaxRate', function(source, cb)
	local xPlayer = ESX.Player(source)
	if not xPlayer then
		cb(Config.TaxRate, nil)
		return
	end

	if IsJobTaxExempt(xPlayer) then
		cb(0, _U('tax_exempt_msg'))
	else
		cb(Config.TaxRate, nil)
	end
end)
