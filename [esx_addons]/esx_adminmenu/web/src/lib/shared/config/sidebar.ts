import PlayersIcon from "../components/icons/PlayersIcon.svelte";
import ServerIcon from "../components/icons/ServerIcon.svelte";
import CarIcon from "../components/icons/CarIcon.svelte";
import type { SidebarOption } from "../types/sidebar";

export const sidebarOptions: SidebarOption[] = [
  {
    label: "Dashboard Home",
    value: "dashboard_home",
    icon: ServerIcon,
  },
  {
    label: "Player Management",
    value: "ply_management",
    icon: PlayersIcon,
    subOptions: [
      { label: "Bans", value: "ply_bans", icon: PlayersIcon },
      { label: "Vehicles", value: "ply_vehicles", icon: CarIcon },
      { label: "Player Search", value: "ply_data", icon: PlayersIcon },
      { label: "Recent Players", value: "ply_recent", icon: PlayersIcon },
    ],
  },
  {
    label: "Server Management",
    value: "srv_management",
    icon: ServerIcon,
  },
];

