fx_version 'adamant'

game 'gta5'
lua54 'yes'
description 'A basic duty system for Jobs'

version '1.0'
legacyversion '1.9.1'

shared_script '@es_extended/imports.lua'

server_scripts {
	'server/main.lua'
}

client_scripts {
	'client/main.lua'
}

dependency 'es_extended'
