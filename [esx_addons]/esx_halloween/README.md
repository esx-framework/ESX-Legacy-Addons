# ESX Halloween Event

Dead players don't have to stay dead. This FiveM/ESX resource adds a ghost respawn system that lets players come back as haunting specters with the ability to terrify the living. Built for performance, security, and fully configurable.

## What This Does

When a player dies, there's a chance they'll be offered a choice: respawn normally, or come back as a ghost. Choose the spectral path and you'll get increased speed, partial invisibility, and the ability to scare nearby players with jump scares. Ghosts can roam for up to 10 minutes before automatically respawning, or they can exit ghost mode whenever they want.

The resource also includes a flexible notification system with Halloween theming, perfect for event-specific messages and alerts.

## Ghost System Breakdown

**The Basics**
Configure spawn chances, ghost duration, visibility range, and movement speed through a straightforward config file. Ghosts use a zombie ped model by default but this can be changed to any model you prefer.

**Visibility Mechanics**
Ghosts aren't fully transparent. They appear at 30% opacity to players within 25 meters, but become completely invisible beyond that range. This creates an effective balance between spookiness and gameplay clarity.

**Movement & Abilities**
Ghost players move 50% faster than normal and can trigger a scare ability using the E key (configurable). The scare has a 30-second cooldown and affects all players within 10 meters, triggering screen shake, sounds, and a brief jumpscare visual effect. When scared, players receive a notification showing which ghost haunted them. Ghosts cannot use weapons or vehicles.

**Admin Controls**
Admins can force the ghost choice dialog on any player using `/ghost [player_id]`. This is useful for events or testing. Permission is tied to ESX groups defined in the config.

## Installation

Standard resource installation applies here:

1. Drop the `esx_halloween` folder into your server's resources directory
2. Add `ensure esx_halloween` to your server.cfg
3. Edit `config.lua` to match your preferences
4. Restart the server

## Configuration

Everything meaningful can be adjusted in `config.lua`:

```lua
Config = {
    Ghost = {
        enabled = true,
        spawnChance = 20,              -- 20% chance on death
        pedModel = 's_m_y_zombie_01',  -- Ped model for ghost
        maxDuration = 600000,          -- 10 minutes

        visibility = {
            range = 25.0,              -- Visibility range in meters
            alpha = 77                 -- Opacity (0-255)
        },

        movement = {
            speedMultiplier = 1.5      -- 1.5x speed
        },

        abilities = {
            scare = {
                enabled = true,
                cooldown = 30000,      -- 30 seconds
                range = 10.0,          -- 10 meters
                keybind = 'E',
                effects = {
                    screenShake = true,
                    sound = true,
                    duration = 3000    -- 3 seconds
                }
            }
        }
    },

    AdminGroups = {
        'admin',
        'superadmin'
    }
}
```

The spawn chance determines how likely a player is to get the ghost option after death. Duration controls the maximum time as a ghost. Visibility settings affect how ghosts appear to other players. Movement multiplier adjusts ghost speed.

## Commands

**`/ghost [player_id]`** (Admin Only)
Triggers the ghost choice dialog. Without an ID, it targets yourself. With an ID, it targets that player. Requires admin or superadmin group membership.

```
/ghost          # Show choice for yourself
/ghost 5        # Show choice for player ID 5
```

## Using Notifications

The notification system can be triggered from any Lua code:

```lua
exports['esx_halloween']:showNotification({
    size = 'small',
    position = 'top-right',
    header = 'Item Received',
    description = 'You found a Halloween candy!',
    duration = 5000
})
```

Notifications support small and large sizes, multiple positioning options (top-left, top-right, top-center, bottom-center), and queue-based display so they don't overlap. Check `EXPORTS.md` for complete export documentation.

## How Ghost Mode Works

**Activation Sequence**
Player dies → system rolls spawn chance → if successful, choice dialog appears → player selects ghost or normal respawn → client requests ghost mode from server → server validates and approves/denies request → client enables ghost mode after server approval.

This request-response pattern prevents exploits and ensures proper server-side validation of all ghost mode activations.

**While Ghosting**
Movement speed increases by 50%. Opacity is set to 30% for nearby players. The scare ability becomes available on E key with a 30-second cooldown. Weapons and vehicles are disabled. A HUD displays remaining time and provides an exit button.

When a ghost uses the scare ability, the target player sees a jumpscare effect and receives a notification 2 seconds later showing which ghost scared them.

**Ending Ghost Mode**
Either the 10-minute timer expires and the player auto-respawns, or the player presses X (configurable) to exit ghost mode early.

## Theme Integration

This resource respects ESX UI theme convars, so it will automatically match your server's color scheme:

- `esx:ui:primaryColor`
- `esx:ui:secondaryColor`
- `esx:ui:backgroundColor`
- `esx:ui:accentColor`
- `esx:ui:logoUrl`

Colors apply automatically on resource start without requiring manual configuration.

## Technical Notes

**Requirements**
ESX Legacy framework, FiveM server with `use_fxv2_oal` support, Lua 5.4.

**Performance Optimizations**
Event-driven architecture means no constant loops. Visibility checks use adaptive intervals: 500ms when ghosts are active, 2000ms when idle. Control disabling runs every frame (Wait(0)) as required by native functions. Model loading has a 10-second timeout. These performance values are hardcoded for optimal balance between responsiveness and resource usage.

**Security Features**
- All ghost mode requests require server-side validation
- Request-response pattern with 5-second timeout prevents client-side exploits
- Cooldown system prevents spam (60s ghost request, 30s scare ability)
- Maximum concurrent ghost limit (configurable, default 10)
- Scare range validation on server-side
- Input sanitization prevents XSS attacks in notifications
- Parameter validation on all exports

**ESX Compliance**
No async code in net events. `use_fxv2_oal 'yes'` is enabled. ESX theme convars are supported. Type definitions are included for better development experience.

**File Structure**
```
esx_halloween/
├── fxmanifest.lua           # Resource manifest
├── config.lua               # Configuration
├── types.lua                # Lua type definitions
├── README.md                # This file
├── EXPORTS.md               # Export documentation
├── shared/
│   └── events.lua          # Centralized event constants
├── client/
│   ├── main.lua            # Notification system
│   ├── ghost.lua           # Ghost system logic
│   ├── respawn.lua         # Respawn handling
│   └── convars.lua         # ESX theme support
├── server/
│   ├── main.lua            # Server initialization
│   ├── ghost.lua           # Ghost state sync & validation
│   ├── commands.lua        # Admin commands
│   └── config_validator.lua # Config validation on start
└── web/
    ├── build/              # Production build
    └── src/                # Svelte 5 source code
```

## Building the UI

If you modify the Svelte source:

```bash
cd web
npm install
npm run build
```

The build output goes to `web/build` and is automatically loaded by the resource.

## Troubleshooting

**Ghost choice not appearing after death**
Check that `Config.Ghost.enabled` is set to true and that spawn chance is above 0. Console errors will indicate if something else is wrong.

**UI elements not rendering**
Verify the resource is actually started with `ensure esx_halloween` in your server.cfg. Check that the `web/build` folder exists and contains the UI files. Browser console (F8) will show any client-side errors.

**Admin command rejected**
Confirm your ESX group is listed in `Config.AdminGroups`. Player IDs must be valid online players. Permission errors will show in chat.

## License

Open source and free to modify. Use it however you need.

## Development Notes

Built for ESX Legacy with modern best practices. Event-driven architecture keeps performance high. Optimized for production servers but easy to extend for custom features.
