# esx_adminmenu

A modern ESX admin menu for FiveM servers.

This resource is built for day-to-day server administration: quick self tools, player moderation, vehicle tools, ban management, server management, and a Svelte dashboard that gives staff a clearer view of what is happening on the server.

It has two UI entry points:

- **Admin Dashboard** - the full NUI dashboard for player lists, bans, vehicles, server tools, and overview cards.
- **Admin Menu** - a smaller keyboard-driven menu for quick actions while staying mostly in-game.

## Features

- Player list, player search, recent players, and detailed player information.
- Player actions such as goto, bring, spectate, kick, ban, revive, freeze, money changes, HP/armor changes, inventory cleanup, routing bucket changes, model changes, and clothing menu access.
- Troll actions are grouped away from the main context menu so the player menu stays usable.
- Ban management with active ban pagination and expiry editing.
- Vehicle list pagination, impound/unimpound/delete tools, `/admincar`, and vehicle ownership support.
- Vehicle spawner and customization tools, including performance levels, turbo, xenon, neon, colors, window tint, wheels, discs, and tires.
- Server management tools for weather, time, blackout, PvP, freeze/unfreeze all, bring all, kick all, kill/revive all, cleanup actions, broadcasts, and money actions.
- Dashboard home page with server and economy overview cards.
- Permission-gated sensitive information such as identifiers and IP addresses.
- Configurable feature permissions, keybinds, revive events, vehicle presets, weather types, limits, and admin groups.
- Frontend error notifications when an NUI callback returns `success = false`.

## Dependencies

Required:

- `es_extended`
- `oxmysql`

Optional integrations:

- `esx_ambulancejob` for revive events.
- `esx_garage` for impound lookups.
- `pma-voice` for radio channel changes and lookups.
- `esx_skin` or your clothing resource for clothing menu events.

## Installation

1. Put the resource in your server resources folder as `esx_adminmenu`. If you keep ESX addons in `[esx_addons]`, that works too.
2. Make sure `es_extended` and `oxmysql` start before this resource.
3. Add this to your `server.cfg` if you are starting it separately:

```cfg
ensure esx_adminmenu
```

4. Configure your admin groups in `shared/config.lua`.
5. Restart the server, or run `refresh` and `ensure esx_adminmenu`.

The resource creates the small database tables it needs on start.

## Permissions

The main permission setup lives in `shared/config.lua`.

- `Config.AllowedGroups` controls who can open the menu.
- `Config.FeaturePermissions` controls who can use specific feature groups.
- `Config.AdminMenu.ActionPermissions`, `Config.PlayerActions.ActionPermissions`, and `Config.ServerManagement.ActionPermissions` map actions to those feature groups.

By default this project is set up around the ESX `admin` group. If your server uses more groups, add them in config instead of hard-coding checks in random files.

## Commands

Menu commands:

- `/admin` opens the small admin menu.
- `/adminmenu` opens the small admin menu.
- `/admindashboard` opens the full dashboard.
- `/information <id>` opens the dashboard directly to a player's information panel.

Player/admin commands:

- `/noclip`
- `/names`
- `/blips`
- `/setmodel <id> <model>`
- `/goto <id>`
- `/bring <id>`
- `/spectate <id>`
- `/stopspectate`
- `/kick <id> <reason>`
- `/ban <id> <duration> <reason>`
- `/notify <id> <message> <type> <duration> <title>`

Helper commands:

- `/vec2`
- `/vec3`
- `/vec4`
- `/heading`
- `/coords` or `/copycoords`
- `/rot` or `/rotation`
- `/model` or `/entitymodel`
- `/vehplate` or `/copyplate`
- `/admincar [model]`
- `/refreshbans` or `/refreshbancache`

## Keybinds

Defaults are configured in `shared/config.lua`:

- Admin Menu: `F9`
- Admin Dashboard: `F10`

Players can change keybinds in their FiveM keybind settings after the commands are registered.

## Revive Setup

Revive is configurable because different ESX servers handle death state differently.

By default, `Config.Revive.Events` triggers:

```lua
"esx_ambulancejob:revive"
```

That event is fired from the server, matching the normal ESX ambulance job command style. A native fallback can also run after a short delay.

## Web Development

The NUI is built with Svelte 5 and Vite.

```powershell
cd web
npm install
npm run dev
npm run check
npm run build
```

The committed resource uses `web/dist` for FiveM. During normal development, run `npm run check` before committing source changes and only rebuild `web/dist` when you want to update the shipped UI assets.

## Notes

This menu is intentionally configurable. Server owners tend to run slightly different ESX stacks, so things like revive, clothing, vehicles, permissions, limits, and integrations should be adjusted in config instead of patched into the core logic.

## License

GPL-3.0. See `LICENSE`.
