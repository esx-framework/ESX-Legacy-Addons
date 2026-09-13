-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
description 'Global ESX death lifecycle, persistence, respawn and branded NUI'
version '1.0.0'
lua54 'yes'

shared_scripts { '@es_extended/imports.lua', '@es_extended/locale.lua', '@esx_lib/imports.lua', 'config.lua', 'locales/*.lua' }
client_scripts { 'client/deathcam.lua', 'client/medal.lua', 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/locales.js', 'web/app.js', 'web/medal.js', 'web/brand-logo.png' }
dependencies { 'es_extended', 'esx_lib', 'oxmysql', '/onesync' }
