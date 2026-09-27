-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'

author 'ESX-Framework'
description 'Provides a way for players to select a job'
lua54 'yes'
version '1.0'
legacyversion '1.16.0'

shared_scripts {
    '@esx_lib/imports.lua',
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua'
}

server_script 'server/main.lua'

client_script 'client/main.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/preview.js',
    'web/assets/*'
}

dependencies {
	'esx_lib',
	'es_extended'
}