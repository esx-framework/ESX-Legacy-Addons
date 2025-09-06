fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

author 'ESX-Framework'
description 'Adds a way for resources to store items for players.'
version '1.1'
legacyversion '1.13.4'

server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'server/classes/addoninventory.lua',
	'server/database.lua',
	'server/main.lua'
}

-- server_exports {
-- 	'GetSharedInventory',
-- 	'AddSharedInventory'
-- }
