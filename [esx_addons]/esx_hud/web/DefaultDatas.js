import {
  ArmorIcon,
  DrinkIcon,
  FoodIcon,
  HealthIcon,
  OxygenIcon,
  StaminaIcon,
} from "./src/assets/Icons";

let defaultConfig = {
  ServerLogo: "",
  Kmh: false,
};

let disableDefaultConfig = {
  Status: false,
  Vehicle: false,
  Weapon: false,
  Position: false,
  Voice: false,
  Money: false,
  Info: false,
  IndicatorSound: false,
  IndicatorSeatbeltSound: false,
  VehicleHandlers: false,
  MinimapOnFoot: false,
  Needle: false,
  Kmh: true,
  StatusPercent: false,
};

const progressColors = {
  healthBar: "red",
  armorBar: "blue",
  drinkBar: "lightblue",
  foodBar: "yellow",
  oxygenBar: "green",
  staminaBar: "purple",
};

const vehDefaultData = {
  show: true,
  fuel: { level: 100, maxLevel: 100 },
  mileage: 5000,
  kmh: false,
  speed: 50,
  rpm: 100,
  damage: 100,
  vehType: "LAND",
};
const hudDefaultData = {
  playerId: 1,
  onlinePlayers: 150,
  serverLogo: "https://esx.s3.fr-par.scw.cloud/blanc-800x800.png",
  moneys: { bank: 75000, money: 100000 },
  weaponData: {
    use: true,
    image: "pistol",
    name: "WEAPON NAME",
    currentAmmo: 32,
    maxAmmo: 128,
    isWeaponMelee: false,
  },
  streetName: "",
  mic: false,
};
const progressLevels = {
  healthBar: 20,
  armorBar: 80,
  drinkBar: 40,
  foodBar: 80,
  oxygenBar: 100,
  staminaBar: 100,
};

const defaultIndicators = {
  tempomat: true,
  door: false,
  light: false,
  engine: false,
  leftIndex: false,
  rightIndex: false,
};

const defaultMenuButtons = [
  {
    name: "Status",
    path: "status",
  },
  {
    name: "Speedo",
    path: "speedo",
  },
  {
    name: "Settings",
    path: "settings",
  },
];

const progressDefaultCircles = [
  {
    name: "healthBar",
    progressLevel: 100,
    color: "red",
    icon: HealthIcon,
    active: false,
  },
  {
    name: "armorBar",
    progressLevel: 100,
    color: "blue",
    icon: ArmorIcon,
  },
  {
    name: "drinkBar",
    progressLevel: 100,
    color: "lightblue",
    icon: DrinkIcon,
  },
  {
    name: "foodBar",
    progressLevel: 100,
    color: "yellow",
    icon: FoodIcon,
  },
  {
    name: "oxygenBar",
    progressLevel: 100,
    color: "pink",
    icon: OxygenIcon,
  },
  {
    name: "staminaBar",
    progressLevel: 100,
    color: "green",
    icon: StaminaIcon,
  },
];

const speedoDefaultColors = [
  {
    name: "segment-color",
    color: "#eee",
  },
  {
    name: "segment-progress-color",
    color: "green",
  },
  {
    name: "number-color",
    color: "#eee",
  },
  {
    name: "danger-color",
    color: "#ff113a",
  },
  {
    name: "danger-progress-color",
    color: "pink",
  },
  {
    name: "number-danger-color",
    color: "#da0b64",
  },
  {
    name: "speedo-progress-color",
    color: "orange",
  },
  {
    name: "damage-progress-color",
    color: "#1be70d",
  },
  {
    name: "engine-icon-color",
    color: "#FEC32C",
  },

  {
    name: "tempomat-icon-color",
    color: "#FEC32C",
  },
  {
    name: "light-icon-color",
    color: "#FEC32C",
  },
  {
    name: "door-icon-color",
    color: "#FEC32C",
  },
  {
    name: "fuel-icon-color",
    color: "white",
  },
  {
    name: "fuel-level-color",
    color: "pink",
  },
  {
    name: "mileage-level-color",
    color: "green",
  },
  {
    name: "unit-color",
    color: "red",
  },
  {
    name: "current-speed-color",
    color: "pink",
  },
  {
    name: "left-right-index-color",
    color: "#00B065",
  },
  {
    name: "damage-icon-color",
    color: "white",
  },
  {
    name: "speedo-background-color",
    color: "rgba(0,0,0,.5)",
  },
  {
    name: "speedo-outer-circle-color",
    color: "#242222",
  },
  {
    name: "speedo-nooble-color",
    color: "#48a3cb",
  },
  {
    name: "speedo-nooble-container",
    color: "#1f2937",
  },
  {
    name: "speedo-seatbelt-icon-color",
    color: "#D22B2B",
  },
];

const allColors = {
  Status: [
    {
      name: "healthBar",
      color: "red",
    },
    {
      name: "armorBar",
      color: "blue",
    },
    {
      name: "drinkBar",
      color: "lightblue",
    },
    {
      name: "foodBar",
      color: "yellow",
    },
    {
      name: "oxygenBar",
      color: "green",
    },
    {
      name: "staminaBar",
      color: "purple",
    },
  ],
  Speedo: [
    {
      name: "segment-color",
      color: "#eee",
    },
    {
      name: "number-color",
      color: "#eee",
    },
    {
      name: "danger-color",
      color: "#ff113a",
    },
    {
      name: "number-danger-color",
      color: "#da0b64",
    },
    {
      name: "speedo-progress-color",
      color: "orange",
    },
    {
      name: "damage-progress-color",
      color: "#1be70d",
    },
    {
      name: "engine-icon-color",
      color: "#FEC32C",
    },

    {
      name: "tempomat-icon-color",
      color: "#FEC32C",
    },
    {
      name: "light-icon-color",
      color: "#FEC32C",
    },
    {
      name: "door-icon-color",
      color: "#FEC32C",
    },
    {
      name: "fuel-icon-color",
      color: "white",
    },
    {
      name: "fuel-level-color",
      color: "pink",
    },
    {
      name: "mileage-level-color",
      color: "green",
    },
    {
      name: "unit-color",
      color: "red",
    },
    {
      name: "current-speed-color",
      color: "pink",
    },
    {
      name: "left-right-index-color",
      color: "#00B065",
    },
    {
      name: "damage-icon-color",
      color: "white",
    },
    {
      name: "speedo-background-color",
      color: "rgba(0,0,0,.5)",
    },
    {
      name: "speedo-outer-circle-color",
      color: "#242222",
    },
  ],
};

export {
  disableDefaultConfig,
  defaultConfig,
  progressColors,
  vehDefaultData,
  hudDefaultData,
  progressLevels,
  defaultIndicators,
  defaultMenuButtons,
  progressDefaultCircles,
  allColors,
  speedoDefaultColors,
};
