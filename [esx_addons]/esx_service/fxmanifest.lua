-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'adamant'

game 'gta5'
lua54 'yes'
description 'A basic duty system for Jobs'

version '1.0'
legacyversion '1.16.0'

shared_script '@es_extended/imports.lua'

shared_script '@esx_lib/imports.lua'
server_scripts {
	'server/main.lua'
}

client_scripts {
	'client/main.lua'
}

dependencies {
	'esx_lib',
	'es_extended'
}
