/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

const fs = require("fs");

const version = process.env.TGT_RELEASE_VERSION;
const newVersion = version.replace("v", "");

const manifestFile = fs.readFileSync("fxmanifest.lua", { encoding: "utf8" });

const newFileContent = manifestFile.replace(/\bversion\s+(.*)$/gm, `version '${newVersion}'`);

fs.writeFileSync("fxmanifest.lua", newFileContent);
