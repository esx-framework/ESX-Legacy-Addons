-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'

author 'ESX-Framework'
description 'Allows Players to use LS Customs to customise their cars'
lua54 'yes'
version '1.0'
legacyversion '1.16.0'

shared_scripts {
	'@esx_lib/imports.lua',
	'@es_extended/imports.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'server/modules/workshop_pricing.lua',
	'server/modules/workshop_validation.lua',
	'server/main.lua'
}

client_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua',
	'client/modules/workshop_locale.lua',
	'client/modules/workshop_stats.lua',
	'client/modules/workshop_camera.lua',
	'client/modules/workshop_vehicle.lua',
	'client/modules/workshop_cart.lua',
	'client/modules/workshop_nui_menu.lua',
	'client/modules/workshop_legacy_menu.lua',
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

dependency 'esx_lib'
