fx_version "cerulean"
game "gta5"
lua54 "yes"

description "The default HUD resource for ESX-Legacy."
version "1.10.2"
legacyversion '1.13.4'

shared_scripts {
    "@es_extended/imports.lua",
    "@es_extended/locale.lua",
    "shared/config.lua",
    "shared/main.lua",
    "locales/*.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/*.lua",
}

client_scripts {
    "client/*.lua",
    "client/player/*.lua",
    "client/vehicle/*.lua",
}

ui_page "web/dist/index.html"

files {
    "web/dist/**",
    "web/dist/assets/**",
}

dependencies {
    "es_extended",
    "esx_status",
    "oxmysql",
}
