-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Allows Players to play animations'
version '1.0'
legacyversion '1.15.0'

shared_script '@esx_lib/imports.lua'
dependency 'es_extended'

client_scripts {
	'@es_extended/imports.lua',
	'config.lua',
	'client/main.lua'
}
