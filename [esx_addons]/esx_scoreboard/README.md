# ESX Scoreboard

A high-performance, modern scoreboard resource for **ESX Legacy**.

![ESX Legacy](https://img.shields.io/badge/ESX-Legacy-orange)
![Svelte](https://img.shields.io/badge/Svelte-5.0-ff3e00?logo=svelte)
![Vite](https://img.shields.io/badge/Vite-7.0-646cff?logo=vite)

---

## Features

- **Modern UI** — Clean, responsive design with CSS variable theming
- **Real-time Search** — Filter players by name, job, or server ID instantly
- **Job Badges** — Visual indicators for player occupations with live counts
- **Activity Tracking** — See ongoing events (robberies, heists, races, etc.)
- **Easy Theming** — Customize colors via CSS variables without touching components
- **ESX Native** — Built specifically for ESX Legacy framework integration

---

## Installation

### 1. Download & Extract

Place the `esx_scoreboard` folder into your server's `resources/` directory.

```
server/
└── resources/
    └── esx_scoreboard/
        ├── client/
        ├── config/
        ├── server/
        ├── web/
        │   ├── dist/           # Compiled production build
        │   └── src/            # Source files (development)
        └── fxmanifest.lua
```

### 2. Build the UI (Development)

Requires **Node.js 18+**:

```bash
cd esx_scoreboard/web
npm install
npm run build
```

For development with hot-reload:

```bash
npm run dev
```

---

## Configuration

Edit `config/main.lua`:

```lua
Config = {}

--- Key to open the scoreboard (default: Z)
Config.OpenKey = "Z"

--- Interval (ms) to broadcast summary counters to open clients
Config.SummaryInterval = 10000

--- Interval (ms) to refresh the visible player page
Config.PageRefreshInterval = 15000

--- Number of open scoreboards refreshed before yielding the server thread
Config.PageRefreshBatchSize = 25

--- Delay (ms) between open-scoreboard refresh batches
Config.PageRefreshBatchDelay = 50

--- Interval (ms) to refresh ping values server-side
Config.PingRefreshInterval = 30000

--- Minimum interval (ms) between player page/search/sort requests
Config.PageRequestCooldown = 1500

--- Player rows sent per page by default and absolute maximum
Config.DefaultPageSize = 50
Config.MaxPageSize = 100
Config.MaxPageCacheEntries = 256
Config.MaxPlayerQueryCacheEntries = 64

--- Server display name shown in the scoreboard header
Config.ServerName = "ESX Server"

--- Max players displayed in the header (set to nil to use sv_maxclients convar)
Config.MaxPlayers = nil

--- HTTPS logo URL shown in the scoreboard header (set to "" to disable)
Config.LogoUrl = ""

--- Enable debug prints on resource start
Config.Debug = false

--- Job color overrides (labels are pulled from ESX.GetJobs() automatically)
Config.Jobs = {
  police    = { color = "#3B82F6" },
  ambulance = { color = "#EF4444" },
  mechanic  = { color = "#F59E0B" },
  taxi      = { color = "#FBBF24" },
  realtor   = { color = "#10B981" },
  cardealer = { color = "#8B5CF6" },
  banker    = { color = "#06B6D4" }
}

--- Activity types that can be shown in the scoreboard
Config.ActivityTypes = {
  robbery  = { label = "Robbery",  icon = "💰" },
  heist    = { label = "Heist",    icon = "🏦" },
  drug     = { label = "Drug Sale", icon = "💊" },
  race     = { label = "Street Race", icon = "🏎️" },
  hostage  = { label = "Hostage",  icon = "🚫" },
  shootout = { label = "Shootout", icon = "🔫" }
}
```

---

## Usage

### Opening the Scoreboard

Press your bound key (default: `Z`) to toggle the scoreboard on/off. Players can rebind this in **Settings → Keybinds → FiveM**.

### Search

Type in the search bar to filter players by:
- **Player name**
- **Job label** (e.g., "Police", "Ambulance")
- **Server ID**

---

## API & Events

### Exports (Server)

Other resources can push activities to the scoreboard:

```lua
-- Start a robbery activity
local activityId = exports.esx_scoreboard:AddActivity("robbery", "Fleeca Bank", "Legion Square", { player1, player2 })

-- Update it
exports.esx_scoreboard:UpdateActivity(activityId, { location = "Downtown" })

-- Remove it
exports.esx_scoreboard:RemoveActivity(activityId)

-- Get all active activities
local activities = exports.esx_scoreboard:GetActiveActivities()
```

---

## Project Structure

```
esx_scoreboard/
├── client/
│   ├── main.lua              # Entry point, threads, NUI callbacks
│   └── module/
│       ├── main.lua          # Scoreboard module (open/close/toggle)
│       ├── class.lua         # Scoreboard class
│       └── enum.lua          # Enums
├── config/
│   └── main.lua              # Configuration
├── server/
│   ├── main.lua              # Entry point
│   └── module/
│       └── main.lua          # Server logic, caches, exports
├── web/
│   ├── dist/                 # Production build (served by FiveM)
│   ├── src/
│   │   ├── components/       # Svelte UI components
│   │   │   ├── Scoreboard.svelte
│   │   │   ├── PlayerRow.svelte
│   │   │   ├── JobBadge.svelte
│   │   │   ├── ActivityBadge.svelte
│   │   │   ├── SearchBar.svelte
│   │   │   ├── Header.svelte
│   │   │   └── Footer.svelte
│   │   ├── stores/
│   │   │   └── scoreboard.js   # Svelte store + derived filters
│   │   ├── styles/
│   │   │   └── variables.css   # CSS custom properties
│   │   ├── App.svelte
│   │   └── main.js
│   ├── package.json
│   ├── vite.config.js
│   └── svelte.config.js
└── fxmanifest.lua
```

---

## Development

### Prerequisites

- [Node.js](https://nodejs.org/) 18+ with npm
- [FiveM](https://fivem.net/) server with ESX Legacy installed

### Setup

```bash
cd [esx_addons]/esx_scoreboard/web
npm install
npm run dev
```

### Build for Production

```bash
npm run build
```

The compiled files are output to `web/dist/` and served by FiveM via `fxmanifest.lua`.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/amazing-feature`
3. Commit your changes using [Conventional Commits](https://www.conventionalcommits.org/)
4. Push to the branch: `git push origin feat/amazing-feature`
5. Open a Pull Request

---

# Legal
### License
esx_scoreboard - scorebaord for ESX

Copyright (C) 2015-2025 Jérémie N'gadi

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.

---

## Credits

- Built for [ESX Legacy](https://github.com/esx-framework/esx-legacy)
- UI powered by [Svelte](https://svelte.dev/) and [Vite](https://vitejs.dev/)
- Original concept by the ESX community
