fx_version 'adamant'
game 'gta5'
description 'Provides a way for players to RP as paramedics (heal/revive players)'
version '1.0.2'
legacyversion '1.14.1'
lua54 'yes'

shared_scripts {
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua'
}

client_scripts {
	'client/*.lua'
}

ui_page 'html/medal.html'

files {
	'html/medal.html',
	'html/medal.js'
}

dependencies {
	'es_extended',
	'esx_skin',
	'esx_vehicleshop'
}
