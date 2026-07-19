fx_version("cerulean")
game("gta5")
lua54("yes")

author("ESX (Zox)")
description("ESX Admin Menu")
version("0.3.2")

shared_scripts({
	"@es_extended/imports.lua",
	"@es_extended/locale.lua",
	"locales/*.lua",
	"shared/*.lua",
})

client_scripts({
	"client/helpers.lua",
	"client/actions.lua",
	"client/nui.lua",
	"client/init.lua",
})

server_scripts({
	"@oxmysql/lib/MySQL.lua",
	"server/helpers.lua",
	"server/ban_cache.lua",
	"server/database.lua",
	"server/actions.lua",
	"server/commands.lua",
	"server/events.lua",
	"server/main.lua",
})

ui_page("web/dist/index.html")

files({
	"web/dist/index.html",
	"web/dist/**/*",
})

dependencies({
	"es_extended",
	"oxmysql",
})
