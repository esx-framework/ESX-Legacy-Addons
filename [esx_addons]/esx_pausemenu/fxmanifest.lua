-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 ESX Framework contributors

fx_version "cerulean"
game "gta5"
lua54 "yes"

use_fxv2_oal "yes"

description "ESX Legacy pause menu"
author "ESX Legacy"
version "1.0.0"
legacyversion "1.16.0"

shared_scripts {
    "@esx_lib/imports.lua",
    "@es_extended/imports.lua",
    "config.lua"
}

client_script "client.lua"
server_script "server.lua"

ui_page "web/index.html"

files {
    "web/index.html",
    "web/styles.css",
    "web/app.js",
    "web/assets/gtavmap.webp",
    "web/assets/esx-logo.png"
}

dependencies {
    "esx_lib",
    "es_extended"
}
