fx_version 'adamant'
game 'gta5'

description 'Allows Players to RP as Police Officers (cars, outfits, handcuffing etc)'
lua54 'yes'
version '1.0.2'
legacyversion '1.13.4'

shared_script '@es_extended/imports.lua'

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'shared/config.lua',
	'shared/constants.lua',
	'shared/permissions.lua',
	'server/*.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'shared/config.lua',
    'client/state.lua',
    'client/boot.lua',
    'client/main.lua',
    'client/vehicle.lua',
    'client/cuffs.lua',
    'client/interactions/*.lua',
    'client/menus/*.lua',
    'client/markers.lua',
    'client/blips.lua',
    'client/objects.lua',
    'client/inputs.lua',
    'client/phone.lua'
}

dependencies {
	'es_extended',
	'esx_billing',
	'esx_vehicleshop'
}