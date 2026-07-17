import type { Component } from "svelte";

export type SidebarOption = {
  label: string;
  value: string;
  icon?: Component | undefined | null;
  subOptions?: SidebarOption[];
};