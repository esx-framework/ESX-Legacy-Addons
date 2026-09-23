-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'

description 'CruiseControl / Seatbelt System for ESX Legacy'

version '1.2'
legacyversion '1.16.0'

lua54 'yes'

shared_script '@esx_lib/imports.lua'
client_scripts {
  '@es_extended/imports.lua',
  '@es_extended/locale.lua',
  'locales/*.lua',
  'config.lua',
  'client/cruisecontrol.lua',
  'client/seatbelt.lua',
  'client/utils.lua',
  'client/keybind.lua'
}

dependencies {
	'esx_lib',
	'es_extended'
}
