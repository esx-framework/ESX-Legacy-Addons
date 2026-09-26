-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'

author 'ESX-Framework'
description 'Allows players to RP as a mechanic (repair and modify vehicles)'
lua54 'yes'
version '1.0'
legacyversion '1.16.0'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua'
}

client_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'client/modules/init.lua',
	'client/modules/utils.lua',
	'client/modules/npc_jobs.lua',
	'client/modules/menus.lua',
	'client/modules/item_actions.lua',
	'client/modules/markers.lua',
	'client/modules/commands.lua'
}

server_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'server/modules/init.lua',
	'server/modules/utils.lua',
	'server/main.lua',
	'server/modules/impound.lua',
	'server/modules/workshop.lua',
	'server/modules/npc_jobs.lua',
	'server/modules/items.lua',
	'server/modules/stock.lua'
}

dependencies {
	'esx_lib',
	'es_extended',
	'esx_society',
	'esx_billing'
}
