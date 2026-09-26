-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'
lua54 'yes'
author 'ESX-Framework'
description 'Allows players to harvest and sell marijuana'
version '1.0.1'
legacyversion '1.16.0'

shared_script '@es_extended/imports.lua'

shared_script '@esx_lib/imports.lua'
server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'server/main.lua'
}

client_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'client/main.lua',
	'client/weed.lua'
}

dependencies {
	'esx_lib',
	'es_extended'
}
