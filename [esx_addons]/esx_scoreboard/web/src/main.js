/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import { mount } from "svelte"
import App from "./App.svelte"
import "./app.css"

const app = mount(App, {
  target: document.getElementById("app")
})

export default app