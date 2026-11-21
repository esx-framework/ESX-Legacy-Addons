-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'esx_vehiclefailure'
author 'ESX-Framework'
description 'Configurable vehicle damage and engine failure'
version '1.0.0'
legacyversion '1.17.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'locales/*.lua',
}

dependencies {
    'es_extended',
}
