-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Allows Players to recieve and Send Bills'
version '1.0'
legacyversion '1.16.0'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'config.lua',
	'locales/*.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/main.lua'
}

client_script 'client/main.lua'

dependencies {
	'esx_lib',
	'es_extended'
}
