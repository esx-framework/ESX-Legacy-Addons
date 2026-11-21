-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'

name 'esx_chat'
author 'ESX Framework'
description 'Standalone ESX chat with OOC, RP, Job, PM, slash suggestions and emoji picker.'
version '1.1.0'
legacyversion '1.17.0'
lua54 'yes'

provide 'chat'
provide 'esx_rpchat'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    '@esx_lib/imports.lua',
    'config.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

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
}
