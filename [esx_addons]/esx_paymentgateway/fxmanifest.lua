-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version "cerulean"
game "gta5"
lua54 "yes"
use_fxv2_oal "yes"

author "ESX-Framework"
description "Payment gateway: a cash or card payment dialog, opened by other resources on the client"
version "1.0.0"
legacyversion "1.16.3"

ui_page "web/dist/index.html"

files {
    "imports.lua",
    "web/dist/index.html",
    "web/dist/**/*",
    "locales/*.lua",
    "client/module/**/*.lua",
    "shared/module/**/*.lua",
}

shared_scripts {
    "@esx_lib/imports.lua",
    "@es_extended/imports.lua",
    "@es_extended/locale.lua",
    "config/main.lua",
}

client_script "client/main.lua"
server_script "server/main.lua"

dependencies {
    "esx_lib",
    "es_extended",
}
