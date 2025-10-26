fx_version "cerulean"
game "gta5"
author "Kenshin13"
description "Weather sync for your ESX server"
version "1.0.0"
legacyversion "1.13.4"
lua54 "yes"
use_fxv2_oal "yes"

shared_scripts {
    "@es_extended/imports.lua",
    "/shared/**",
    "config/main.lua",
}

client_scripts {
    "/client/modules/**",
    "client/main.lua",
}

ui_page "ui/index.html"

files {
    -- Keep this order.
    "ui/index.html",
    "ui/style.css",
    "ui/css/*.css",
    "ui/js/core/state.js",
    "ui/js/core/constants.js",
    "ui/js/utils/sanitizer.js",
    "ui/js/utils/helpers.js",
    "ui/js/services/nui-bridge.js",
    "ui/js/controllers/ui-controller.js",
    "ui/js/handlers/event-handlers.js",
    "ui/js/main.js",
}

server_scripts {
    "/server/modules/**",
    "server/main.lua",
}

dependencies {
    "es_extended",
}
