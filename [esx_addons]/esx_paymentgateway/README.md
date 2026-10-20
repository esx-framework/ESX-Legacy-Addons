# esx_paymentgateway

A cash or card payment dialog for other resources. The player sees what they pay for, their
balances and what stays after paying, and picks how to pay. That is all the gateway decides.
Whether the sale happens is up to the resource that opened the dialog: it checks price, stock,
distance and the chosen account on its own server and takes the money there with
`xPlayer.chargeAccount`.

The groundwork comes from cs0ng0r's first version.

[EXAMPLES.md](EXAMPLES.md) has two complete shops, one for each way of using it.

## Setup

Start it after its dependencies:

```cfg
ensure esx_lib
ensure es_extended
ensure esx_paymentgateway
```

The page is served from `web/dist`, which is committed, so nothing has to be built on the server.
Selling needs an es_extended that has `xPlayer.chargeAccount`.

## In game

The player picks a method with the mouse, the arrow keys or `1` and `2`, and pays with Enter.
Payments of `Config.HoldAmount` or more need the pay button, Enter or Space held until it has
filled. Esc cancels. The dialog also closes when the player dies or logs out of their character,
and when the resource that opened it stops.

The dialog only takes the mouse and keyboard once it shows the payment. Should the page be unable
to show one, or not confirm it within 10 seconds, the export returns `false, "cancelled"` instead
of leaving the player stuck.

## Opening the dialog

`RequestPayment` is a client export. It waits until the player is done, so call it from a thread:

```lua
CreateThread(function()
    local account, reason = exports.esx_paymentgateway:RequestPayment({
        amount = 1250,                          -- whole number, at least 1
        title = "Vehicle repair",               -- what is paid for
        description = "Los Santos Customs",     -- optional, who is paid
        currency = "$",                         -- optional, Config.Currency by default
        methods = { "money", "bank" },          -- optional, ESX accounts, every configured one by default
    }, onPay)                                   -- optional, see below
end)
```

It returns the ESX account the player chose, `"money"` (shown as cash) or `"bank"` (shown as
card), or `false` and a reason:

| Reason | |
|---|---|
| `"cancelled"` | The player closed the dialog, died, logged out, or your resource stopped |
| `"unconfirmed"` | Your `onPay` failed or did not answer in time; it may have sold anyway |
| `"busy"` | Another dialog is open on this client |
| anything else | The request is broken, e.g. `"A title is required, at most 120 bytes."` |

Title and description take up to 120 bytes of UTF-8, the currency up to 4. Optional fields you
pass are checked like the required ones: a broken one refuses the request instead of being left out.

The balances in the dialog come from ESX's player data on the client. They are there for the
player to read, nothing more: the real check happens on your server when you charge.

### Just the method

Without `onPay`, the dialog closes as soon as the player confirms a method and the export
returns its account. You send it to your server, sell there and tell the player how it went
yourself, usually with a notification. Good for small things where a receipt would be in the way.

### With a receipt

With `onPay`, the dialog stays open after the pick and shows Processing while `onPay` runs.
`onPay` gets the account, asks your server to sell, and returns how that went:

| `onPay` returns | The dialog |
|---|---|
| `true`, or `{ ok = true }` | Shows the receipt |
| `true, { reference = "LSC-0042" }`, or `{ ok = true, reference = "LSC-0042" }` | Shows the receipt with your reference on it |
| `false, "Sold out"`, or `{ ok = false, message = "Sold out" }` | Shows the reason; the player can pick another method or cancel |
| `false, "insufficient_funds"`, or `{ ok = false, reason = "insufficient_funds" }` | The same, with the dialog's own text for that failure of `chargeAccount` |
| anything else, an error, or nothing within `Config.PayTimeout` | Closes and tells the player to check before paying again |

The table form is there so `onPay` can hand back what your server callback returned without
unpacking it. Only return `false` when you know no money was taken. If the answer is unclear,
let it error or time out: the player then cannot pay a second time from the same dialog.

The export returns the account once the player closes the receipt, or when they die or log out
while `onPay` still runs and it sold.

## Charging on the server

The resource that sells takes the money itself, with es_extended's `xPlayer.chargeAccount`:

```lua
--- The accounts your shop takes. The client sends whatever it likes, black_money too.
local ACCOUNTS = { money = true, bank = true }

local player = ESX.Player(source)
if not player or not ACCOUNTS[account] then
    return { ok = false, reason = "invalid_account" }
end

local charged, failure = player.chargeAccount(account, price, "Vehicle repair")
if not charged then
    return { ok = false, reason = failure }
end
```

Call it after your own checks, with the price from your server's data, never one the client sent.
It takes the money only when the account covers it and never throws. When it does not charge,
`failure` says why, and `{ ok = false, reason = failure }` is what the dialog explains:

| `failure` | |
|---|---|
| `"insufficient_funds"` | The account holds less than the price |
| `"invalid_account"` | The player has no such account |
| `"invalid_amount"` | Not a whole number from 1 up |
| `"session_closing"` | The player is leaving and being saved |
| `"failed"` | ESX or the inventory refused, see the console |

Treat anything but `true` as not charged: a player looked up with `ESX.Player` who left in the
meantime gets the call back with nothing at all.

To give money back, for when you charged but could not hand over what was bought, use
`player.addAccountMoney(account, amount, reason)`. It returns `false` when it cannot, for example
when ox_inventory has no room for the cash; log that, since the money is then lost unless an admin
steps in.

For logging and audit, ESX fires `esx:removeAccountMoney` on the server with the player, the
account, the amount and your reason for every charge.

### Why the gateway keeps no payments

An earlier version held every payment open on the server with an id, an expiry and the
character it was for, and took the money itself. That still left the real question to the
shop, only later: a payment opened two minutes ago says nothing about whether the last car is
still in stock when the player finally presses pay. Your server has to check that at the moment
it takes the money anyway, so it might as well take it. The gateway stays a dialog.

Taking the money lives in es_extended for a similar reason. From any other resource, every step
of a safe charge (is the player loaded, the balance, the account guard, the removal, the guard
again, the balance again) is a separate trip through msgpack. `chargeAccount` does all of it
inside es_extended, so your server pays two trips: `ESX.Player` and the call.

## Config

| Option | Default | |
|---|---|---|
| `Config.Accounts` | `cash = "money", card = "bank"` | ESX account behind each look, one account each; requests and answers use these names |
| `Config.Methods` | `{ "cash", "card" }` | Order of the looks, and the ones offered at all |
| `Config.Currency` | `"$"` | Symbol when a request names none |
| `Config.HoldAmount` | `50000` | From this amount the pay button has to be held; `0` turns it off |
| `Config.PayTimeout` | `20` | Seconds the dialog waits for `onPay`, `3` to `300`; after that the payment is unconfirmed |
| `Config.CloseDelay` | `2600` | Milliseconds the receipt stays, up to `30000`; `0` waits for the player |
| `Config.Volume` | `0.5` | Volume of the dialog's sounds, `0` to `1` |
| `Config.TestCommand` | `false` | Registers `/testpayment <amount> [money\|bank\|both] [select]` for admins |

The config is checked at start on both sides: values that would break a payment are reported in
the console and replaced by their defaults.

`/testpayment` charges the admin's own money through `xPlayer.chargeAccount`. It shows the
receipt, or with `select` only picks and reports the result as a notification. The amount stays on
the server, the way a shop keeps its prices; the client only names the account.

## Languages

The texts follow the `esx:locale` convar; English and German are included, and amounts are grouped
the same way. For another language, copy `locales/en.lua` to `locales/<code>.lua` and translate
the values. Keys it leaves out fall back to English.

## Theme

The dialog follows the ESX UI convars. Set them with `setr` so clients can read them:

```cfg
setr esx:ui:primaryColor "#FB9B04"
setr esx:ui:secondaryColor "#252525"
setr esx:ui:backgroundColor "#161616"
setr esx:ui:accentColor "#383838"
setr esx:ui:logoUrl "https://example.com/logo.png"
```

Colors are `#rgb` or `#rrggbb`; the logo has to be an `http(s)://` or `nui://` URL.

## Working on the page

The page is Svelte 5 with the ESX UI kit, built for FiveM's CEF 103.

```sh
cd web
npm ci
npm run dev        # http://localhost:3000, plays a demo payment
npm test           # unit tests
npm run test:cef   # builds and plays the dialog in Chromium 103
npm run build      # type check, build to dist/, Chromium 103 feature check
```

Outside FiveM the page runs a demo by itself: it opens sample payments, answers like a shop with
a receipt (the fuel stop only takes the pick) and offers a server theme and the German texts.
`npm run build` fails on CSS or JavaScript features Chromium 103 lacks and on source files over
400 lines.
