/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import type { Component } from "svelte";

export type SidebarOption = {
  label: string;
  value: string;
  icon?: Component | undefined | null;
  subOptions?: SidebarOption[];
};