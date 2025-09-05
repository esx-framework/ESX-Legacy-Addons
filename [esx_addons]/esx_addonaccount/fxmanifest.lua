fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

author 'ESX-Framework'
description 'Allows resources to store account data, such as society funds.'
version '1.2'
legacyversion '1.13.4'

server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'server/classes/addonaccount.lua',
	'server/database.lua',
	'server/main.lua'
}
