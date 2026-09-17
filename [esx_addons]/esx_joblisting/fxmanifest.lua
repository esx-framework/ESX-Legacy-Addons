-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'

description 'Provides a way for players to select a job through a NUI job centre'
lua54 'yes'
version '2.0.0'
legacyversion '1.15.0'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua'
}

client_scripts {
	'client/nui.lua',
	'client/main.lua'
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/css/*.css',
	'html/js/*.js',
	'html/vendor/*',
	'html/assets/*'
}

dependencies {
	'esx_lib',
	'es_extended'
}