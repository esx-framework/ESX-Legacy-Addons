-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

PaymentGateway = {}

if IsDuplicityVersion() then
    local missingApiReported = false

    local function isCallable(value)
        if type(value) == 'function' then
            return true
        end

        local metatable = type(value) == 'table' and getmetatable(value)

        return type(metatable) == 'table' and type(metatable.__call) == 'function'
    end

    function PaymentGateway.Charge(player, account, amount, reason)
        if account ~= 'money' and account ~= 'bank' then
            return false, 'invalid_account'
        end

        if not player then
            return false, 'session_closing'
        end

        if not isCallable(player.chargeAccount) or not isCallable(player.isCurrent) then
            if not missingApiReported then
                local message = '[%s] Payment unavailable: '
                    .. 'es_extended player payment API is missing. '
                    .. 'Deploy the updated es_extended with chargeAccount '
                    .. 'and restart the full server to recreate player sessions.'

                print(message:format(GetCurrentResourceName()))
                missingApiReported = true
            end

            return false, 'payment_unavailable'
        end

        if player.isCurrent() ~= true then
            return false, 'session_closing'
        end

        if amount == 0 then
            return true
        end

        return player.chargeAccount(account, amount, reason)
    end

    function PaymentGateway.Refund(player, account, amount, reason)
        if amount == 0 then
            return true
        end

        local ok, refunded = pcall(player.addAccountMoney, account, amount, reason)

        if not ok or refunded ~= true then
            print(
                ('[%s] Refund requires review: %s, %s, %s'):format(
                    GetCurrentResourceName(),
                    player.getIdentifier(),
                    account,
                    amount
                )
            )
            return false
        end

        return true
    end

    return
end

local pending = false

function PaymentGateway.NotifyFailure(reason, message)
    if reason == 'cancelled' or reason == 'busy' then
        return
    end

    if reason == 'payment_unavailable' then
        ESX.ShowNotification('Payment service unavailable. Please contact server staff.', 'error')
        return
    end

    if reason == 'unconfirmed' then
        ESX.ShowNotification(
            'Payment not confirmed. Check your purchase before paying again.',
            'error'
        )
        return
    end

    if reason == 'insufficient_funds' then
        ESX.ShowNotification(message)
        return
    end

    if reason == 'not_near_shop' then
        ESX.ShowNotification('You are too far from this shop.', 'error')
        return
    end

    ESX.ShowNotification('Purchase could not be completed. Please try again.', 'error')
end

function PaymentGateway.Select(request)
    if request.amount == 0 then
        return 'money'
    end

    request.methods = request.methods or { 'money', 'bank' }

    return exports.esx_paymentgateway:RequestPayment(request)
end

function PaymentGateway.Await(request, callbackName, ...)
    if pending then
        return false, 'busy'
    end

    local arguments = table.pack(...)
    local quote = request.quote

    pending = true
    request.quote = nil

    if quote then
        local ok, amount =
            pcall(xLib.callback.await, quote, false, table.unpack(arguments, 1, arguments.n))

        if not ok or type(amount) ~= 'number' then
            pending = false
            return false, 'invalid_quote'
        end

        request.amount = amount
    end

    local ok, account, failure = pcall(PaymentGateway.Select, request)

    if not ok or not account then
        pending = false
        return false, failure or 'cancelled'
    end

    arguments.n = arguments.n + 1
    arguments[arguments.n] = account

    local result = table.pack(
        pcall(xLib.callback.await, callbackName, false, table.unpack(arguments, 1, arguments.n))
    )

    pending = false

    if not result[1] then
        print(
            ('[%s] Payment result unconfirmed: %s'):format(
                GetCurrentResourceName(),
                tostring(result[2])
            )
        )
        return false, 'unconfirmed'
    end

    if result[2] == false and result[3] ~= 'insufficient_funds'
        and result[3] ~= 'busy' and result[3] ~= 'cancelled' then
        print(('[%s] Purchase rejected (%s): %s'):format(
            GetCurrentResourceName(), callbackName, tostring(result[3] or 'unspecified')
        ))
    end

    return table.unpack(result, 2, result.n)
end

function PaymentGateway.Pay(request, callbackName, callback, ...)
    if pending then
        callback(false, 'busy')
        return
    end

    local arguments = table.pack(...)

    CreateThread(function()
        callback(
            PaymentGateway.Await(request, callbackName, table.unpack(arguments, 1, arguments.n))
        )
    end)
end
