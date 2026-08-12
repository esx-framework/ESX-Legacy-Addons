fx_version 'cerulean'
game 'gta5'

description 'ESX Shops - Modern modular shop system with NUI for ESX Legacy'
lua54 'yes'
use_fxv2_oal 'yes'
version '2.0.0'
legacyversion '1.14.1'

shared_scripts {
	'@es_extended/imports.lua',
	'shared/locale.lua',
	'shared/config/main.lua',
	'shared/config/shops.lua',
	'shared/functions.lua',
	'shared/modules/*.lua',
	'shared/compat.lua'
}

client_scripts {
	'client/functions.lua',
	'client/modules/*.lua',
	'client/compat.lua',
	'client/main.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/functions.lua',
	'server/modules/*.lua',
	'server/compat.lua',
	'server/main.lua'
}

ui_page 'web/dist/index.html'

files {
	'web/dist/**/*',
	'web/images/**/'
}

dependency 'es_extended'
