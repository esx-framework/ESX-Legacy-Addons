-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'adamant'

game 'gta5'

description 'Handles the overall status system for Hunger, Thrist and others'

version '1.1'
legacyversion '1.16.0'

lua54 'yes'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'config.lua',
	'server/main.lua'
}

client_scripts {
	'config.lua',
	'client/classes/status.lua',
	'client/main.lua'
}

ui_page 'html/ui.html'

files {
	'html/ui.html',
	'html/css/app.css',
	'html/scripts/app.js'
}

dependencies {
	'esx_lib',
	'es_extended'
}
