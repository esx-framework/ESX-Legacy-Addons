-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ESX-Framework'
description 'Standalone ESX radial accessory and clothing manager'
version '1.0.0'
legacyversion '1.16.0'

shared_scripts {
    '@esx_lib/imports.lua',
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/catalog.lua',
    'client/wardrobe.lua',
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/assets/icons/*.png'
}

dependencies { 'esx_lib', 'es_extended', 'skinchanger' }
