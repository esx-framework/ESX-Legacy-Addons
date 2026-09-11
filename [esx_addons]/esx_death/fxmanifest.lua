-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
description 'Global ESX death lifecycle, persistence, respawn and branded NUI'
version '1.0.0'

shared_scripts { '@es_extended/imports.lua', 'config.lua' }
client_scripts { 'client/deathcam.lua', 'client/medal.lua', 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js', 'web/medal.js', 'web/brand-logo.png' }
dependencies { 'es_extended', 'oxmysql', '/onesync' }
