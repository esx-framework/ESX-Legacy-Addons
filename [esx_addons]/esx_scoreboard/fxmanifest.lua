-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version "cerulean"
game "gta5"

use_fxv2_oal "yes"

lua54 "yes"

description "ESX Scoreboard with active jobs, robberies and activities"
author "ESX Team"
version "1.0.0"
legacyversion "1.15.0"

shared_scripts {
  '@esx_lib/imports.lua',
  "@es_extended/imports.lua",
  "config/main.lua"
}

client_scripts {
  "client/main.lua"
}

server_scripts {
  "server/main.lua"
}

ui_page "web/dist/index.html"

files {
  "web/dist/index.html",
  "web/dist/assets/*",
  "web/dist/*.png",
  "client/module/*.lua"
}

dependency {
  "esx_lib",
  "es_extended"
}
