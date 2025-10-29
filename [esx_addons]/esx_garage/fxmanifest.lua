fx_version 'cerulean'
game 'gta5'

author 'ESX-Framework'
description 'Modern Garage System with React UI'
use_experimental_fxv2_oal 'true'

version '2.0.0'
legacyversion '1.13.4'

lua54 'yes'

-- React NUI
ui_page 'web/dist/index.html'
-- ui_page 'http://localhost:3000'
files {
    'web/dist/index.html',
    'web/dist/**/*',
    'vehicleImages/**/*',
    'locales/*.lua',
}

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'client/modules/**/*',
    'client/init.lua'
}
