fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

description 'ESX Halloween Event - Ghost Mode & Trick-or-Treat'
version '2.0.0'

ui_page 'web/build/index.html'

files {
    'web/build/**/*'
}

shared_script '@es_extended/imports.lua'

shared_scripts {
    'shared/events.lua',
    'types.lua',
    'configs/trickortreat.lua',
    'config.lua'
}

client_scripts {
    'client/convars.lua',
    'client/respawn.lua',
    'client/ghost.lua',
    'client/trickortreat.lua',
    'client/main.lua'
}

server_scripts {
    'server/config_validator.lua',
    'server/main.lua',
    'server/ghost.lua',
    'server/trickortreat.lua',
    'server/commands.lua'
}
