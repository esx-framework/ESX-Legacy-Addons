fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

description 'ESX Halloween Event - Ghost Mode & Scare System'
version '1.0.0'

ui_page 'web/build/index.html'

files {
    'web/build/**/*'
}

shared_script '@es_extended/imports.lua'

shared_scripts {
    'shared/events.lua',
    'types.lua',
    'config.lua'
}

client_scripts {
    'client/convars.lua',
    'client/respawn.lua',
    'client/ghost.lua',
    'client/main.lua'
}

server_scripts {
    'server/config_validator.lua',
    'server/main.lua',
    'server/ghost.lua',
    'server/commands.lua'
}
