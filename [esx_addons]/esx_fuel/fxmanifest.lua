-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'esx_fuel'
author 'ESX Framework'
description 'Fuel system with pumps, fuel types and consumption'
version '1.0.0'
legacyversion '1.17.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    '@esx_lib/imports.lua',
    'config.lua',
    'shared/mix.lua',
}

client_scripts {
    'client/main.lua',
    'client/mix.lua',
    'client/pump/main.lua',
    'client/pump/hose.lua',
    'client/pump/refuel.lua',
    'client/pump/ui.lua',
    'client/pump/interact.lua',
    'client/jerrycan.lua',
    'client/stock.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    'es_extended',
    'esx_lib',
    'oxmysql',
}
