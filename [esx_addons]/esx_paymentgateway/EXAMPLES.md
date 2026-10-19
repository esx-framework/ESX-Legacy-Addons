# Examples

Two small shops, one for each way of using the dialog. Each has what a shop needs around it: a
shared config, the client and the server. The prices and places are made up.

The idea is the same in both. The client asks the player how they want to pay. The server
checks everything again at the moment it sells, takes the money with `Charge` and hands over
what was bought. The gateway never knows what is sold.

## A car wash: just the method

Washing a car costs little and the player can see the result, so a receipt would only be in the
way. The dialog closes on the pick and the wash answers with a notification.

`shared/config.lua`

```lua
Config = {}
Config.WashPoint = vector3(26.5, -1392.0, 29.3)
Config.WashPrice = 150
```

`client/main.lua`

```lua
local function wash()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return end

    local method = exports.esx_paymentgateway:RequestPayment({
        amount = Config.WashPrice,
        title = "Car wash",
        description = "Hands On Car Wash",
    })
    if not method then return end -- they closed the dialog, nothing to do

    local result = xLib.callback.await("carwash:wash", false, method)
    if result.ok then
        SetVehicleDirtLevel(vehicle, 0.0)
        ESX.ShowNotification("Your car is clean.", "success")
    else
        ESX.ShowNotification(result.message, "error")
    end
end

-- however you trigger it: a marker, a target, a key
RegisterCommand("wash", function()
    CreateThread(wash)
end)
```

`server/main.lua`

```lua
xLib.callback.register("carwash:wash", function(source, method)
    local ped = GetPlayerPed(source)
    if GetVehiclePedIsIn(ped, false) == 0 then
        return { ok = false, message = "You need to sit in a car." }
    end
    if #(GetEntityCoords(ped) - Config.WashPoint) > 8.0 then
        return { ok = false, message = "Drive into the wash first." }
    end

    -- The price comes from the config here, not from the client.
    local charged, _, message = exports.esx_paymentgateway:Charge(source, method, Config.WashPrice, "Car wash")
    if not charged then
        return { ok = false, message = message }
    end
    return { ok = true }
end)
```

The amount in `RequestPayment` is only what the player sees. Someone who edits their client can
show themselves any price they like, the server still charges `Config.WashPrice`.

## A car dealer: with a receipt

A car is expensive, there are only a few of each, and the player wants to see that it went
through. So the dialog stays open while the server sells, and shows the plate on the receipt.

This is also where the order on the server matters. Two players can press pay for the last car
at the same moment, and the database can fail after the money was taken. The dealer takes the
car off the stock first, then the money, then writes the car to the player, and undoes the
earlier steps when a later one fails.

`shared/config.lua`

```lua
Config = {}
Config.Showroom = vector3(-33.7, -1102.0, 26.4)
Config.Cars = {
    zentorno = { label = "Pegassi Zentorno", price = 185000 },
    sultan = { label = "Karin Sultan", price = 32000 },
}
```

The stock lives in a `dealer_stock` table with a `model` and an `amount` column.

`client/main.lua`

```lua
local function buy(model)
    local car = Config.Cars[model]

    local method = exports.esx_paymentgateway:RequestPayment({
        amount = car.price,
        title = car.label,
        description = "Premium Deluxe Motorsport",
        methods = { "card" }, -- nobody brings a bag of cash for a supercar
    }, function(method)
        -- Runs while the dialog shows Processing. The table the server sends back is
        -- exactly what the dialog wants: { ok, message } or { ok, reference }.
        return xLib.callback.await("dealer:buy", false, model, method)
    end)

    if method then
        ESX.ShowNotification(("Your %s is waiting outside."):format(car.label), "success")
    end
end

RegisterCommand("buycar", function(_, args)
    if Config.Cars[args[1]] then CreateThread(function() buy(args[1]) end) end
end)
```

`server/main.lua`

```lua
local function putBack(model)
    MySQL.update.await("UPDATE dealer_stock SET amount = amount + 1 WHERE model = ?", { model })
end

xLib.callback.register("dealer:buy", function(source, model, method)
    local car = Config.Cars[model]
    if not car then
        return { ok = false, message = "We do not sell that one." }
    end
    -- The client only offers card, but it could send anything.
    if method ~= "card" then
        return { ok = false, message = "Card only, sorry." }
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - Config.Showroom) > 10.0 then
        return { ok = false, message = "Come to the showroom." }
    end

    -- Only one of two players pressing pay at once gets the last car.
    local reserved = MySQL.update.await(
        "UPDATE dealer_stock SET amount = amount - 1 WHERE model = ? AND amount > 0", { model })
    if reserved ~= 1 then
        return { ok = false, message = "Sold out." }
    end

    local charged, _, message = exports.esx_paymentgateway:Charge(source, method, car.price, car.label)
    if not charged then
        putBack(model)
        return { ok = false, message = message }
    end

    local plate = GeneratePlate() -- your own, or the one esx_vehicleshop uses
    local stored, rows = pcall(MySQL.update.await,
        "INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)", {
            ESX.Player(source).getIdentifier(),
            plate,
            json.encode({ model = GetHashKey(model), plate = plate }),
        })
    if not stored or rows ~= 1 then
        exports.esx_paymentgateway:Refund(source, method, car.price, car.label .. " (refund)")
        putBack(model)
        return { ok = false, message = "That went wrong, your money is back." }
    end

    return { ok = true, reference = plate }
end)
```

When the dealer says sold out, the dialog shows it under the methods and the player can cancel.
When the money is short, `Charge` already has the text for it. When the callback throws, or
hangs past `Config.PayTimeout`, the dialog closes and tells the player to check before paying
again. The dealer may well have sold in that case, and then the car is in their garage.

## Things that bite

- `RequestPayment` waits until the player is done. Run it in its own thread with `CreateThread`,
  so whatever called it does not hang for that long.
- Return `false` from `onPay` only when you know no money was taken. Anything unclear should
  error or return nothing, so the player cannot pay twice from the same dialog.
- Check the method on the server. The client sends whatever it wants, also a method your shop
  did not offer. `Charge` only refuses methods the whole server does not take.
- Take prices from your server's data. The amount the dialog showed came from the client.
- Only one dialog is open at a time. A second `RequestPayment` while one is up returns
  `false, "busy"`.
