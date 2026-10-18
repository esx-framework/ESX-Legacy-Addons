# esx_paymentgateway

A cash or card payment dialog that other resources open from the server. The player sees what
they pay for, their balances and what stays after paying, and picks a method; the server checks
the balance, takes the money and tells the resource that asked how the payment ended.

The groundwork, the export and its result event, comes from cs0ng0r's first version.

## Setup

Start it after its dependencies:

```cfg
ensure esx_lib
ensure es_extended
ensure esx_paymentgateway
```

The page is served from `web/dist`, which is committed, so nothing has to be built on the server.

## In game

The player picks a method with the mouse, the arrow keys or `1` and `2`, and pays with Enter.
Payments of `Config.HoldAmount` or more need the pay button, Enter or Space held until it has
filled. Esc cancels. The dialog also closes when the payment expires, when the player dies or logs
out of their character, and when the resource that opened it stops. After paying, the receipt
closes itself after `Config.CloseDelay`.

The dialog only takes the mouse and keyboard once it shows the payment. Should the page ever be
unable to show one, the payment ends as `cancelled` right away instead of leaving the player stuck.

## Opening a payment

```lua
local opened, detail = exports.esx_paymentgateway:RequestPayment(playerId, {
    amount = 1250,                          -- whole number, at least 1
    title = "Vehicle repair",               -- what is paid for
    description = "Los Santos Customs",     -- optional, who is paid
    currency = "$",                         -- optional, Config.Currency by default
    methods = { "cash", "card" },           -- optional, every configured method by default
}, function(playerId, success, method, request, outcome)
    if success then
        -- method is "cash" or "card"; deliver what was bought
    end
end)

if not opened then
    print(detail) -- why it did not open
end
```

`RequestPayment` returns `true` and the payment id when the dialog opened, or `false` and a reason
when the player is not available, already has a payment open, or the request is invalid. A player
has at most one open payment, and it belongs to the character it was opened for: if the player
logs out to another character, it ends as `dropped` and the new character is never charged.

### The result

The function passed as third argument is called once when the payment ends. This is the safe way
to hear the result, since nothing outside the server can call it.

| Argument | |
|---|---|
| `playerId` | The player who paid or did not |
| `success` | `true` once the money was taken |
| `method` | `"cash"` or `"card"`, `nil` unless paid |
| `request` | `id`, `amount`, `currency`, `title`, `description`, `methods` |
| `outcome` | `"paid"`, `"cancelled"`, `"expired"`, `"dropped"` or `"stopped"` |

`stopped` means esx_paymentgateway itself stopped while the payment was open. Do not wait inside the
function; start a thread for anything slow. An error in it is logged and does not undo the payment.

A refused method (not enough money, or ESX refusing to take it) does not end the payment; the player
can pick another method or cancel. `success` is only `true` when ESX confirmed taking the money, or,
on versions that do not confirm, when the balance dropped by exactly the amount.

For compatibility, a request may also name a `resultEvent`. It fires on the server with the same
arguments. Register it with `AddEventHandler`, never `RegisterNetEvent`: a net event of that name
could be triggered by clients.

### Cancelling

```lua
exports.esx_paymentgateway:CancelPayment(playerId)
```

Ends the player's open payment, e.g. when they walk away from the shop, and returns `true`. Only the
resource that opened the payment can cancel it; the result arrives as `cancelled`. It returns `false`
when the player has no open payment or another resource opened it.

### Logging

Every payment that went through fires a local server event, for logging and audit resources:

```lua
AddEventHandler("esx_paymentgateway:paid", function(payment)
    -- payment.playerId, payment.identifier, payment.id, payment.amount, payment.method,
    -- payment.account, payment.title, payment.resource
end)
```

## Config

| Option | Default | |
|---|---|---|
| `Config.Accounts` | `cash = "money", card = "bank"` | ESX account each method takes the money from |
| `Config.Methods` | `{ "cash", "card" }` | Order of the methods, and the default set |
| `Config.Currency` | `"$"` | Symbol when a request names none |
| `Config.HoldAmount` | `50000` | From this amount the pay button has to be held; `0` turns it off |
| `Config.Timeout` | `120` | Seconds before an open payment expires, at least `10`; the dialog shows the time left |
| `Config.CloseDelay` | `2600` | Milliseconds the receipt stays; `0` waits for the player |
| `Config.Volume` | `0.5` | Volume of the dialog's sounds, `0` to `1` |
| `Config.TestCommand` | `false` | Registers `/testpayment <amount> [cash\|card]` for admins |

The config is checked at start: values that would break a payment are reported in the console and
replaced by their defaults.

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

Colors are `#rgb` or `#rrggbb`; the logo has to be an `https://` or `nui://` URL.

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

Outside FiveM the page runs a demo by itself: it opens sample payments, answers like the server
and offers a server theme and the German texts. `npm run build` fails on CSS or JavaScript
features Chromium 103 lacks and on source files over 400 lines.
