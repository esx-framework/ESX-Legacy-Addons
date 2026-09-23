-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'

description 'ESX Weapon Shop - Modern modular weapon shop with NUI for ESX Legacy'
lua54 'yes'
version '1.0'
legacyversion '1.16.0'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'shared/config/main.lua',
	'shared/config/weapon_images.lua',
	'shared/config/shops.lua',
	'shared/config/upgrades.lua',
	'shared/functions.lua'
}

client_scripts {
	'client/functions.lua',
	'client/modules/blips.lua',
	'client/modules/markers.lua',
	'client/modules/nui.lua',
	'client/modules/interactions.lua',
	'client/main.lua'
}

server_scripts {
	'server/functions.lua',
	'server/modules/validation.lua',
	'server/modules/inventory.lua',
	'server/modules/transactions.lua',
	'server/main.lua'
}

ui_page 'web/dist/index.html'

files {
	'web/dist/**/*'
}

dependencies {
	'esx_lib',
	'es_extended',
	'esx_license',
	'/onesync'
}
