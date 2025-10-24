fx_version "cerulean"
game "gta5"
author "Kenshin13"
description "Weather sync for your ESX server"
version "1.0.0"
legacyversion "1.13.4"
lua54 "yes"

shared_scripts {
    "@es_extended/imports.lua",
    "/shared/**",
    "config/main.lua",
}

client_scripts {
    "/client/modules/**",
    "client/main.lua",
}

server_scripts {
    "/server/modules/**",
    "server/main.lua",
}

dependencies {
    "es_extended",
}
