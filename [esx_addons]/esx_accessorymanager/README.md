# ESX Accessory Manager

A new, standalone FiveM resource implementing the supplied radial wardrobe design.
It does not replace or require `esx_accessories` and does not change accessory shops.

## Installation

Place `esx_accessorymanager` in your server resources and start it after its dependencies:

```cfg
ensure esx_lib
ensure es_extended
ensure skinchanger
ensure esx_accessorymanager
```

Uses the local ESX library's `xLib.nui` and `xLib.addKeybind` APIs. There is no SQL
migration, server callback, build step, CDN, or Node dependency at runtime.

Open with **F11** or `/accessories`. Rebind through FiveM's key bindings settings.
The default avoids the original `esx_accessories` J and `esx_adminmenu` F9 bindings.
Escape or clicking outside closes the menu. Tab/arrows navigate; Enter/Space activates
the focused option.

## Behavior

- Thirteen sectors arranged radially with exported PNG icons.
- Orange hover with black icons. A removed item stays dark with a light icon;
  clicking it again restores the original drawable and texture.
- Watch, glasses, mask, necklace, earrings, pants, shoes, top/arms, hat, bag, undershirt,
  bracelet and vest use the current character's skinchanger fields.
- Clothing changes play a short configurable animation before the item is removed
  or restored.
- The center restores all items removed by this resource during the current outfit.
- The tools button reapplies current props, including cleared slots. The hair button
  reapplies the current hairstyle, texture and colors without reloading the model.
- Vest visibility does not grant, refill or remove gameplay armor.
- Unavailable items are disabled. No arbitrary drawable, texture, model or event name
  is accepted from the UI. Only allowlisted action identifiers are handled.
- The menu is blocked while dead, cuffed, ragdolling, falling, paused, inventory-busy,
  or using another focused NUI. Vehicles are blocked by default.
- Focus is released on close, death, logout, external skin events and resource stop.
- No idle frame loop: the menu checks state every 200 ms only while visible.

The white background belongs only to browser preview mode. In FiveM the background is transparent.
The interface follows the `esx:locale` convar; English and Spanish are included. Other locales
can add the same keys in `locales/`, with English as the fallback. Colors follow the `esx:ui:*` theme convars.

## Appearance Integration

Supports the male and female freemode models through this project's `skinchanger`
`GetSkin` and `LoadClothes` exports. Default undressed drawables are in `config.lua`;
adjust them for custom clothing packs. Values are checked against the active ped.

Changes update skinchanger, but this resource does not save a permanent outfit or
sell/create clothing. Remembered items are held in memory, survive menu close/open,
and are restored on resource stop when the current outfit still matches. Changing
character or applying a new outfit discards the old removal history. Disconnects
use the appearance resource's normal saved skin.

The resource observes `skinchanger:loadSkin` and `skinchanger:loadClothes` events and
detects changed skin fields on the next operation. A resource that loads an outfit
directly through exports should explicitly invalidate the history, especially when
loading an outfit whose empty fields match the currently removed items:

```lua
exports.esx_accessorymanager:CloseAccessoryMenu()
exports.esx_accessorymanager:InvalidateWardrobe()
-- Apply your new outfit here.
```

## Client API

```lua
exports.esx_accessorymanager:OpenAccessoryMenu()
exports.esx_accessorymanager:CloseAccessoryMenu()
exports.esx_accessorymanager:InvalidateWardrobe()
TriggerEvent('esx_accessorymanager:openMenu')
```

## Structure

| Path | Responsibility |
| --- | --- |
| `config.lua` | Language, command, key, restrictions, animations and undressed values |
| `locales/` | English and Spanish UI messages |
| `client/catalog.lua` | Ordered categories, slots and locale lookup |
| `client/wardrobe.lua` | Validation, snapshots, restoration and skinchanger bridge |
| `client/main.lua` | NUI callbacks, lifecycle, focus and action cooldown |
| `html/js/` | Radial geometry, transport, interaction and browser preview fixture |
| `html/assets/` | Exported icons used by the radial interface |

## Preview

Open `html/index.html?preview=1` directly in a browser for the interactive design preview.
No web server is necessary. Its sample states do not represent a connected character.

Code is GPL-3.0-only. The icons are supplied through the user's Figma file; their
original ownership and license remain with their respective creators.
