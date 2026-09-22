<h1 align='center'>[ESX] Job Listing</a></h1><p align='center'><b><a href='https://discord.esx-framework.org/'>Discord</a> - <a href='https://documentation.esx-framework.org/legacy/installation'>Documentation</a></b></h5>

Job Center NUI based on the [Figma design](https://www.figma.com/design/bXbaHpIVBLnEthVpv6DHjd/Untitled?node-id=0-1): welcome, job details, player profile, task notification and task panel. The 905 × 683 panel scales with the original 1920 × 1080 canvas; the game remains visible behind it. All fonts and graphics are bundled locally. The ESX logo is reused from `esx_scoreboard`.

## Installation and preview

Restart `esx_joblisting` after copying the resource. Requires the existing `es_extended` and `esx_lib` resources. No npm build, database migration or internet connection is needed by the interface.

Open `web/index.html?preview=1` through a local web server for the Figma sample data. Add `&hud=1` for both task overlays. Preview data is disabled inside FiveM, even if a preview parameter is present. Without the parameter, the interface starts hidden.

## Jobs and player data

The menu lists existing non-whitelisted ESX jobs with grade 0. Job changes are checked on the server for valid jobs, whitelist and proximity, and the UI only reports success after confirmation. Applying for the same job does not reset the player's rank. Escape and the close button release NUI focus, as does stopping the resource.

`Config.JobDetails[jobName]` optionally supplies `subtitle`, `description`, `image` (a local `assets/...` path), `rating` (0–5), `location = {x, y}`, `requirement` (display text) and `tasks`. A mining presentation is included. Job names, labels and salaries come from ESX; other jobs use a neutral ESX image until configured. A requirement label is informational and does not create a new license restriction.

The profile uses the player's ESX name, server ID, date of birth, sex, phoneNumber variable, job, grade and salary. Unavailable personal information and statistics display `—`. Interface text comes from `locales/*.lua` (selected by `esx:locale`); colors and logo follow the `esx:ui:*` theme convars. Quit Job assigns `Config.UnemployedJob` (default `unemployed`).

## Task and statistics integration

The original resource does not track mining tasks, earnings or hours worked. Existing job resources can supply authoritative data through this **server export**, stored in ESX player metadata per job:

```lua
exports.esx_joblisting:UpdateJobProgress(source, 'miner', {
    stats = {
        earnings = 150400,
        minutes = 872,
        days = 8,
        extra = {{label = 'Resources sold', value = '240'}}
    },
    tasks = {
        {title = 'Get 40 diamonds', description = 'Collect diamonds at the mine.', current = 20, target = 40}
    }
})
```

These are display snapshots supplied by the job resource, not rewards granted by this menu. Nothing awards money or progress from browser input. The original `esx_joblisting:getJobsList` callback and `esx_joblisting:setJob` event remain supported.

Optional **client exports** display the Figma task overlays without taking focus:

```lua
exports.esx_joblisting:ShowTasks(tasks, 'Senior Miner')
exports.esx_joblisting:HideTasks()
exports.esx_joblisting:ShowTaskProgress({title = 'Get diamonds', current = 20, target = 40})
```

Task notifications hide after five seconds. The task panel remains visible until hidden by its owning job resource.

## Validation

The server regression test can run with Lua 5.3+ from the resource directory:

```sh
lua -e "dofile('tests/server.lua'); dofile('server/main.lua'); verifyJobListing()"
```

Browser validation covers all three views, local asset loading, 720p/1080p/1440p and ultrawide scaling, apply/quit, Escape, empty jobs, text escaping, failed requests and closing while an application is pending. An in-game check is still required for the actual FiveM focus, marker and ESX deployment.

## Legal

esx_joblisting - virtual Job Center!

Copyright (C) 2015-2025 Jérémie N'gadi, ESX-Framework

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.
