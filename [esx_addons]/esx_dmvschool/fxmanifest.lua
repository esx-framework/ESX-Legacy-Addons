-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
author 'ESX-Framework'
description 'Driving school with supervised manoeuvres and road tests'
version '2.0.0-dev.5'
legacyversion '1.16.3'
lua54 'yes'

shared_scripts {
  '@es_extended/imports.lua',
  '@esx_lib/imports.lua',
  '@es_extended/locale.lua',
  'config.lua',
  'shared/*.lua',
}

client_scripts {
  'client/interaction.lua',
  'client/markers.lua',
  'client/main.lua',
}
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/theory.lua',
  'server/vehicles.lua',
  'server/main.lua',
}

ui_page 'html/ui.html'
files {
  'locales/*.lua',
  'html/ui.html',
  'html/styles.css',
  'html/scripts.js',
  'html/icons.js',
  'html/assets/esx-logo.png',
  'html/assets/*.txt',
  'html/assets/fonts/*.ttf',
  'html/assets/fonts/OFL.txt',
}

dependencies { 'esx_lib', 'es_extended', 'esx_license', 'esx_textui', 'oxmysql' }
