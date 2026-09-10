# Workshop UI

The NUI uses the ESX palette from `esx_shops`, `esx_weaponshop`, `esx_adminmenu`
and `esx_banking`: #FB9B04, #161616, #252525, #383838, #969696 and #F2F2F2.
Vehicle customization, live statistics and camera controls follow the workshop
flow of `rc_taller`. The selection summary and separate review panel take
inspiration from the [Porsche configurator](https://configurator.porsche.com/en-US/mode/model/95BAU1).

## Modules

- `html/js/app.js`: NUI messages, navigation, localization and serialized requests.
- `html/js/catalog.js`: searchable list/grid, selection states and color swatches.
- `html/js/cart.js`: expandable cart, badge, total and checkout controls.
- `html/js/icons.js`: category-to-Lucide mapping and SVG creation.
- `client/modules/workshop_locale.lua`: ESX locale payload for the interface.
- `client/modules/workshop_camera.lua`: camera behavior and active-view messages.

All new text lives in `locales/*.lua`. English is the default. Browser code only
displays prices received from Lua; the existing server-side checkout remains
responsible for validating purchases. Opening the cart never initiates payment.
The cart starts collapsed for each workshop session. Escape closes the cart
first, then clears a search, then exits the workshop.

## Local Assets

- `assets/esx-logo.png` is an unchanged copy of
  `esx_skin/web/src/assets/icons/logo-esx.png`.
- Roboto fonts are copied from `esx_garage/web/src/assets/fonts`.
- `vendor/lucide.min.js` is Lucide 1.8.0, distributed under its included LICENSE.

No CDN, web font service, frontend build or additional FiveM resource is needed.

## Verification

With Playwright installed, run `node tests/ui-smoke.cjs`. For an existing browser,
set `CHROME_PATH` to its executable. `PLAYWRIGHT_PATH` can point to an existing
Playwright installation. Screenshots are written to `tests/artifacts` by default.
The test uses simulated NUI responses and covers selection, cart state, search,
camera actions, localization, network errors and desktop/mobile sizing.

In FiveM, restart `esx_lscustom` after updating the resource. Verify actual vehicle
previews, paid modifications, cancellation, and returning from free camera with E.
Browser checks do not execute GTA natives or validate an ESX server session.
