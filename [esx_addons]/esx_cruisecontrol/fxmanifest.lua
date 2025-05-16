fx_version 'cerulean'
game 'gta5'

description 'CruiseControl / Seatbelt System for ESX Legacy'

version '1.2'
legacyversion '1.9.5'

lua54 'yes'

client_scripts {
  '@es_extended/imports.lua',
  '@es_extended/locale.lua',
  'locales/*.lua',
  'config.lua',
  'client/cruisecontrol.lua',
  'client/seatbelt.lua',
  'client/utils.lua',
  'client/keybind.lua'
}

dependencies {
  'es_extended'
}