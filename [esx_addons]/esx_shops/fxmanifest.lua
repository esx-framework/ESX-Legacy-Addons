fx_version 'cerulean'
game 'gta5'

description 'ESX Shops - Modern shop system with NUI for ESX Legacy'
lua54 'yes'
use_fxv2_oal 'yes'
version '2.0.0'
legacyversion '1.13.4'

shared_scripts {
	'@es_extended/imports.lua',
	'shared/types.lua',
	'config.lua'
}

client_scripts {
	'client/main.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/main.lua'
}

ui_page 'web/dist/index.html'

files {
	'web/dist/**/*'
}

dependency 'es_extended'
