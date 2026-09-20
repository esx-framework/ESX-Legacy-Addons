-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Allows Players to play animations'
version '1.1'
legacyversion '1.15.0'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua'
}
dependency 'es_extended'

client_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'client/modules/nui.lua',
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/css/style.css',
	'html/js/*.js',
	'html/vendor/lucide.min.js',
	'html/vendor/LICENSE',
	'html/assets/*'
}
