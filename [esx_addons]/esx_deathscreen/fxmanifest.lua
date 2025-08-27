fx_version 'cerulean'
game 'gta5'

description 'My really cool script'

lua54 'yes'

shared_scripts {
  '@es_extended/imports.lua',
  '@es_extended/locale.lua',
  'config.lua',
  'locales/*.lua',
}

client_scripts {
  'client/main.lua',
  'client/deathcam.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
}

dependencies {
  'es_extended'
}