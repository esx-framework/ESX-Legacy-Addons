fx_version 'bodacious'
game 'gta5'

description 'Provides a way for players to select a job'
lua54 'yes'
version '1.0'
legacyversion '1.9.1'

shared_scripts {
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua'
}

server_script 'server/main.lua'

client_script 'client/main.lua'

dependency 'es_extended'
