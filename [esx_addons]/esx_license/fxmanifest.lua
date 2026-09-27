-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'

game 'gta5'

author 'ESX-Framework'
description 'Handles logic for player licenses, such as: Driving License, gun license and more'
lua54 'yes'
version '1.0'
legacyversion '1.16.0'

shared_script '@esx_lib/imports.lua'
server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'config.lua',
	'server/main.lua'
}

dependencies {
	'esx_lib',
	'es_extended',
	'oxmysql'
}
