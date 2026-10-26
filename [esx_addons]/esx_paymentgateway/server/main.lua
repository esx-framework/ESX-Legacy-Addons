-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--- Server entry. The dialog lives on the client and moves no money: the resource that sells
--- something checks the purchase and charges with xPlayer.chargeAccount on its own server.
--- README.md documents the export and EXAMPLES.md shows a seller.

local Validate = require "shared.module.validate.main"

Validate.config()

if Config.TestCommand then
    require "server.module.test.main"
end
