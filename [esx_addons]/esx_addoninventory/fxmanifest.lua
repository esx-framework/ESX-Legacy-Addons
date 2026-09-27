-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'
author 'ESX-Framework'
description 'Adds a way for resources to store items for players'
lua54 'yes'
version '1.0'
legacyversion '1.16.0'

server_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'server/classes/addoninventory.lua',
	'server/main.lua'
}

server_exports {
	'GetSharedInventory',
	'AddSharedInventory'
}

dependencies {
	'esx_lib',
	'es_extended'
}
