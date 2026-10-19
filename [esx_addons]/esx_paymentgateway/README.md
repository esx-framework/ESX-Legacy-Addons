# esx_paymentgateway

A cash or card payment dialog for other resources. The player sees what they pay for, their
balances and what stays after paying, and picks how to pay. That is all the gateway decides.
Whether the sale happens is up to the resource that opened the dialog: it checks price, stock,
distance and the chosen method on its own server and takes the money there, with `Charge` if
it likes.

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

## In game

The player picks a method with the mouse, the arrow keys or `1` and `2`, and pays with Enter.
Payments of `Config.HoldAmount` or more need the pay button, Enter or Space held until it has
filled. Esc cancels. The dialog also closes when the player dies or logs out of their character,
and when the resource that opened it stops.

The dialog only takes the mouse and keyboard once it shows the payment. Should the page ever be
unable to show one, the export returns `nil, "cancelled"` right away instead of leaving the player
stuck.

## Opening the dialog

`RequestPayment` is a client export. It waits until the player is done, so call it from a thread:

```lua
CreateThread(function()
    local method, reason = exports.esx_paymentgateway:RequestPayment({
        amount = 1250,                          -- whole number, at least 1
        title = "Vehicle repair",               -- what is paid for
        description = "Los Santos Customs",     -- optional, who is paid
        currency = "$",                         -- optional, Config.Currency by default
        methods = { "cash", "card" },           -- optional, every configured method by default
    }, onPay)                                   -- optional, see below
end)
```

It returns the method, `"cash"` or `"card"`, or `nil` and a reason:

| Reason | |
|---|---|
| `"cancelled"` | The player closed the dialog, died, logged out, or your resource stopped |
| `"unconfirmed"` | Your `onPay` failed or did not answer in time; it may have sold anyway |
| `"busy"` | Another dialog is open on this client |
| anything else | The request is broken, e.g. `"A payment title is required."` |

The balances in the dialog come from ESX's player data on the client. They are there for the
player to read, nothing more: the real check happens on your server when you charge.

### Just the method

Without `onPay`, the dialog closes as soon as the player confirms a method and the export
returns it. You send it to your server, sell there and tell the player how it went yourself, usually
with a notification. Good for small things where a receipt would be in the way.

### With a receipt

With `onPay`, the dialog stays open after the pick and shows Processing while `onPay` runs.
`onPay` gets the method, asks your server to sell, and returns how that went:

| `onPay` returns | The dialog |
|---|---|
| `true`, or `{ ok = true }` | Shows the receipt |
| `true, { reference = "LSC-0042" }`, or `{ ok = true, reference = "LSC-0042" }` | Shows the receipt with your reference on it |
| `false, "Sold out"`, or `{ ok = false, message = "Sold out" }` | Shows the reason; the player can pick another method or cancel |
| anything else, an error, or nothing within `Config.PayTimeout` | Closes and tells the player to check before paying again |

The table form is there so `onPay` can hand back what your server callback returned without
unpacking it. Only return `false` when you know no money was taken. If the answer is unclear,
let it error or time out: the player then cannot pay a second time from the same dialog.

The export returns the method once the player closes the receipt, or when they die or log out
while `onPay` still runs and it sold.

## Charging on the server

```lua
local charged, failure, message = exports.esx_paymentgateway:Charge(playerId, method, amount, "Vehicle repair")
```

Takes `amount` from the ESX account of `method` (`Config.Accounts`) and proves it left the
account. Call it after your own checks, with the price from your server's data, never one the
client sent. The method comes from the client too, so make sure your shop takes it.

On failure, `message` is a text for the player in the server's language, and `failure` says why:

| `failure` | |
|---|---|
| `"insufficient"` | Not enough money for that method |
| `"method"` | Not a method this server takes payments in |
| `"amount"` | Not a whole number of at least 1 |
| `"player"` | No such player |
| `"failed"` | ESX refused or the balance did not move by the amount, see the console |

```lua
exports.esx_paymentgateway:Refund(playerId, method, amount, "Vehicle repair")
```

Gives money back to the same account, for when you charged but could not hand over what was
bought. It returns `false` and warns in the console when ESX refuses, since that money is then
lost unless an admin steps in.

Every successful `Charge` fires a local server event, for logging and audit resources:

```lua
AddEventHandler("esx_paymentgateway:paid", function(payment)
    -- payment.playerId, payment.identifier, payment.amount, payment.method,
    -- payment.account, payment.reason, payment.resource
end)
```

### Why the gateway keeps no payments

An earlier version held every payment open on the server with an id, an expiry and the
character it was for, and took the money itself. That still left the real question to the
shop, only later: a payment opened two minutes ago says nothing about whether the last car is
still in stock when the player finally presses pay. Your server has to check that at the moment
it takes the money anyway, so it might as well take it. The gateway stays a dialog.

## Config

| Option | Default | |
|---|---|---|
| `Config.Accounts` | `cash = "money", card = "bank"` | ESX account each method shows and charges |
| `Config.Methods` | `{ "cash", "card" }` | Order of the methods, and the ones the server takes at all |
| `Config.Currency` | `"$"` | Symbol when a request names none |
| `Config.HoldAmount` | `50000` | From this amount the pay button has to be held; `0` turns it off |
| `Config.PayTimeout` | `20` | Seconds the dialog waits for `onPay`, at least `3`; keep it longer than your callback timeout |
| `Config.CloseDelay` | `2600` | Milliseconds the receipt stays; `0` waits for the player |
| `Config.Volume` | `0.5` | Volume of the dialog's sounds, `0` to `1` |
| `Config.TestCommand` | `false` | Registers `/testpayment <amount> [cash\|card\|both] [select]` for admins |

The config is checked at start on both sides: values that would break a payment are reported in
the console and replaced by their defaults.

`/testpayment` charges the admin's own money through `Charge`. It shows the receipt, or with
`select` only picks and reports the result as a notification.

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

Outside FiveM the page runs a demo by itself: it opens sample payments, answers like a shop with
a receipt (the fuel stop only takes the pick) and offers a server theme and the German texts.
`npm run build` fails on CSS or JavaScript features Chromium 103 lacks and on source files over
400 lines.
