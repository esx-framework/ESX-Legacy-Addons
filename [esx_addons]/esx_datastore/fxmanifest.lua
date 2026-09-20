-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'adamant'

game 'gta5'

description 'Used for storing Data, such as society inventories'

version '1.0'
legacyversion '1.16.0'


lua54 'yes'

shared_script '@esx_lib/imports.lua'
server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'server/classes/datastore.lua',
	'server/main.lua'
}

dependency 'esx_lib'
