fx_version 'cerulean'
game 'gta5'

description 'ESX Weapon Shop - Modern modular weapon shop with NUI for ESX Legacy'
lua54 'yes'
version '1.0'
legacyversion '1.14.1'

shared_scripts {
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'shared/config/main.lua',
	'shared/config/shops.lua',
	'shared/functions.lua'
}

client_scripts {
	'client/functions.lua',
	'client/modules/*.lua',
	'client/main.lua'
}

server_scripts {
	'server/functions.lua',
	'server/modules/*.lua',
	'server/main.lua'
}

ui_page 'web/dist/index.html'

files {
	'web/dist/**/*'
}

dependency 'es_extended'
