fx_version 'cerulean'
game 'gta5'

author 'ESX-Framework'
description 'Modern Garage System with React UI'
use_experimental_fxv2_oal 'true'

version '2.0.0'
legacyversion '1.14.2'

lua54 'yes'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/**/*',
    'locales/*.lua',
}

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/modules/*.lua'
}

client_scripts {
    'client/modules/**/*',
    'client/init.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}