-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ESX-Framework'
description 'Allows Players to buy & sell vehicles'
version '1.0'
legacyversion '1.17.0'

shared_scripts {
    '@esx_lib/imports.lua',
    '@es_extended/imports.lua',
    '@esx_paymentgateway/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'shared/dealerships.lua',
    'shared/rentals.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@esx_lib/imports/catalog/bootstrap.lua',
    'server/modules/state.lua',
    'server/schema.lua',
    'server/modules/migrations.lua',
    'server/modules/catalog.lua',
    'server/modules/access.lua',
    'server/modules/orders.lua',
    'server/modules/payments.lua',
    'server/modules/management.lua',
    'server/modules/test_drive.lua',
    'server/modules/compatibility.lua',
    'server/timed_rentals/state.lua',
    'server/timed_rentals/database.lua',
    'server/timed_rentals/service.lua',
    'server/timed_rentals/main.lua',
    'server/main.lua',
    'server/rental_payments.lua',
}

client_scripts {
    'client/utils.lua',
    'client/state.lua',
    'client/preview.lua',
    'client/test_drive.lua',
    'client/timed_rentals.lua',
    'client/compatibility.lua',
    'client/main.lua',
}

dependencies {
    'esx_lib',
    'es_extended',
    'esx_paymentgateway',
    'esx_garage',
}

ui_page 'web/index.html'
files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/*',
    'web/rentals/**/*',
}

export 'GeneratePlate'
