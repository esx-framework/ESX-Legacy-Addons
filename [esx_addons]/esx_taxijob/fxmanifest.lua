-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'

author 'ESX-Framework'
description 'Allows players to be a taxi driver (Pickup and drop-off NPCs)'
lua54 'yes'
version '1.0'
legacyversion '1.17.0'

shared_scripts {
    '@esx_lib/imports.lua',
    '@es_extended/imports.lua',
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    '@esx_garage/integrations/config.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@esx_lib/imports/catalog/bootstrap.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    '@esx_garage/integrations/config.lua',
    'server/*.lua',
    '@esx_garage/integrations/server.lua',
}

dependencies {
    'esx_garage',
    'esx_datastore',
    'esx_society',
    'esx_lib',
    'es_extended',
}
