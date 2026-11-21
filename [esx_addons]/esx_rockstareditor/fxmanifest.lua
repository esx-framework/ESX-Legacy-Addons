-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ESX-Framework'
description 'Rockstar Editor recording menu for ESX Legacy'
version '1.0.0'
legacyversion '1.17.0'

shared_scripts {
    '@esx_lib/imports.lua',
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/recording.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/*.ttf',
    'web/assets/esx-logo.png',
}

dependencies {
    'esx_lib',
    'es_extended',
}
