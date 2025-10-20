fx_version 'cerulean'
game 'gta5'

author 'ESX-Framework'
description 'Modern Garage System with React UI'

version '2.0.0'
legacyversion '1.13.4'

lua54 'yes'

-- React NUI
ui_page 'web/dist/index.html'
files {
    'web/dist/index.html',
    'web/dist/**/*'
}

shared_script '@es_extended/imports.lua'

server_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'client/nui_callbacks.lua',
    'client/nui_events.lua'
}
