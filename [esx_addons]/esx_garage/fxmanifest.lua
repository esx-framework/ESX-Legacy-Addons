fx_version 'cerulean'
game 'gta5'

author 'ESX-Framework'
description 'Allows Players to Store & Retrieve their vehicles'

version '1.0'
legacyversion '1.13.4'

lua54 'yes'
ui_page 'nui/index.html'
files { 'nui/index.html', 'nui/**/*' }

shared_script '@es_extended/imports.lua'

server_scripts { '@es_extended/locale.lua', 'locales/*.lua', '@oxmysql/lib/MySQL.lua', 'config.lua', 'server/main.lua' }

client_scripts { '@es_extended/locale.lua', 'locales/*.lua', 'config.lua', 'client/main.lua' }
