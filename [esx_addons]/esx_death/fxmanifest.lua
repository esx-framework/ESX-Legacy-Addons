-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'

author 'ESX-Framework'
description 'Global ESX death lifecycle, persistence, respawn and branded NUI'
version '1.0.0'
lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    '@esx_lib/imports.lua',
    'config.lua'
}

client_scripts {
    'client/deathcam.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'locales/*.lua',
    'web/index.html',
    'web/style.css',
    'web/locales.js',
    'web/app.js',
    'web/brand-logo.png',
    'web/assets/DSEG7Classic-Bold.ttf'
}

dependencies {
    'es_extended',
    'esx_lib',
    'oxmysql',
    '/onesync'
}