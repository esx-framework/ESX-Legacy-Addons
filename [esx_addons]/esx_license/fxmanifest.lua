fx_version 'adamant'

game 'gta5'

description 'Handles for logic for player licenses, such as: Driving License, gun license and more'
lua54 'yes'
version '1.0'
legacyversion '1.9.1'

server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'config.lua',
	'server/main.lua'
}
