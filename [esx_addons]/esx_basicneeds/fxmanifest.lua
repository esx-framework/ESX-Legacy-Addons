-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'

author 'ESX-Framework'
description 'Hunger, thirst, consumables and alcohol effects'
lua54 'yes'
version '1.0'
legacyversion '1.17.0'

provide 'esx_optionalneeds'

shared_script '@es_extended/imports.lua'

shared_script '@esx_lib/imports.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@esx_lib/imports/catalog/bootstrap.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'server/main.lua',
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'client/main.lua',
    'client/alcohol.lua',
}

dependencies {
    'esx_lib',
    'es_extended',
    'esx_status',
}
