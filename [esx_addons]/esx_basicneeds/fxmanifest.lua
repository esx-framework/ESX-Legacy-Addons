-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'

author 'ESX-Framework'
description 'Adds a Hunger & Thirst system'
lua54 'yes'
version '1.0'
legacyversion '1.16.0'

shared_script '@es_extended/imports.lua'

shared_script '@esx_lib/imports.lua'
server_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'client/main.lua'
}

dependencies {
	'esx_lib',
	'es_extended',
    'esx_status'
}
