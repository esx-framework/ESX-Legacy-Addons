-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'adamant'

game 'gta5'

description 'Provides basic Jobs For Players to RP as.'
lua54 'yes'
version '1.0'
legacyversion '1.15.0'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'jobs/*.lua',
}
server_scripts {
	'server/main.lua',
}

client_scripts {
	'client/main.lua',
}

dependencies {
	'esx_lib',
	'es_extended',
	'/onesync'
}
