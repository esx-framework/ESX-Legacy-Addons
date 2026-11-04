-- SPDX-License-Identifier: GPL-3.0-only
-- Driving examinations, vehicle models and routes.
Config = {}

-- Resolve regional Spanish/English codes while retaining the bundled zh-cn file.
local configuredLocale = GetConvar('esx:locale', 'en'):lower():gsub('_', '-')
Config.Locale = configuredLocale == 'zh-cn' and configuredLocale or configuredLocale:match('^[^-]+')
Config.DrawDistance = 20.0
Config.SpeedMultiplier = 3.6
Config.SpeedUnit = 'km/h'

-- Examination rules. Times are in milliseconds; speeds use Config.SpeedUnit.
Config.MaxErrors = 5
Config.ExamTimeout = 20 * 60 * 1000
Config.SpeedTolerance = 5
Config.SpeedingGrace = 2500
Config.DamageThreshold = 20
Config.DamageCooldown = 2000
Config.AbandonTimeout = 20000
Config.SpeedLimits = { residence = 50, town = 80, freeway = 120 }

-- Native task markers. These settings affect presentation, not exam rules.
Config.Markers = {
  enabled = true,
  drawDistance = 250.0,
  detailDistance = 65.0,
  fadeDistance = 35.0,
  groundInterval = 1000,
}

-- Prevent simultaneous examinations across the independent ESX schools.
Config.SchoolResources = { 'esx_dmvschool', 'esx_boatschool', 'esx_flightschool' }
Config.School = {
  id = 'dmv',
  title = 'school_name',
  icon = 'car',
  menu = vector4(239.471, -1380.960, 32.741, 140.0),
  returnPos = vector4(237.80, -1380.48, 33.74, 140.0),
  blip = { sprite = 408, colour = 0, scale = 0.85 },
  instructor = 's_m_m_highsec_01',
}

-- Labels refer to locale keys. Licence identifiers match esx_license.
Config.Licenses = {
  {
    id = 'dmv',
    kind = 'theory',
    label = 'license_dmv',
    price = 500,
    icon = 'book-open',
    bank = 'road',
    questionCount = 10,
    answersNeeded = 5,
  },
  {
    id = 'drive',
    kind = 'practical',
    label = 'license_drive',
    price = 2500,
    icon = 'car',
    requires = 'dmv',
    model = 'blista',
    route = 'car',
    instructor = true,
    -- Model footprint and local XY bounding-box centre.
    dimensions = { width = 1.76, length = 4.11, offset = { x = 0.0, y = 0.088 } },
    spawn = vector4(249.409, -1407.230, 30.4094, 317.0),
  },
  {
    id = 'drive_bike',
    kind = 'practical',
    label = 'license_drive_bike',
    price = 3000,
    icon = 'motorbike',
    requires = 'dmv',
    model = 'sanchez',
    route = 'bike',
    instructor = false,
    dimensions = { width = 1.2, length = 2.8 },
    spawn = vector4(249.409, -1407.230, 30.4094, 317.0),
  },
  {
    id = 'drive_truck',
    kind = 'practical',
    label = 'license_drive_truck',
    price = 5000,
    icon = 'truck',
    requires = 'dmv',
    model = 'mule3',
    route = 'truck',
    instructor = true,
    -- The Mule3 bounding-box centre is behind its entity origin.
    dimensions = { width = 2.72, length = 8.08, offset = { x = 0.0, y = -0.2193 } },
    spawn = vector4(245.65, -1411.15, 30.4094, 317.0),
  },
}
Config.Routes = {}

-- Use normal vehicle entry and prepare the vehicle after driver binding.

local function createTask(id, kind, coords, label, instruction, options)
  local task = { id = id, type = kind, pos = coords, label = label, instruction = instruction }
  for key, value in pairs(options or {}) do
    task[key] = value
  end
  return task
end
local preparationTask =
  createTask('prepare', 'engine', vector3(249.409, -1407.230, 29.5), 'task_prepare_label', 'task_prepare_instruction')

-- Existing painted bay. mapBay adds no props or ground geometry.
local parkingBay = { coords = vector3(237.577, -1411.856, 29.586), width = 3.2, length = 4.6, heading = 326.43 }
Config.Routes.car = {
  preparationTask,
  createTask(
    'leave',
    'navigate',
    vector3(271.0, -1371.0, 30.9),
    'task_car_leave_label',
    'task_car_leave_instruction',
    { radius = 14, limit = 30 }
  ),
  createTask(
    'junction',
    'stop',
    vector3(235.5, -1346.5, 29.5),
    'task_car_junction_label',
    'task_car_junction_instruction',
    { radius = 7, hold = 2000, limit = 50, visual = true }
  ),
  createTask(
    'urban',
    'navigate',
    vector3(216.5, -1410.2, 28.3),
    'task_car_urban_label',
    'task_car_urban_instruction',
    { radius = 16, limit = 50 }
  ),
  createTask(
    'approach',
    'navigate',
    vector3(241.5, -1405.6, parkingBay.coords.z),
    'task_car_approach_label',
    'task_car_approach_instruction',
    { radius = 5, limit = 15 }
  ),
  createTask('reverse_park', 'park', parkingBay.coords, 'task_park_label', 'task_car_reverse_park_instruction', {
    width = parkingBay.width,
    length = parkingBay.length,
    heading = parkingBay.heading,
    headingTolerance = 16,
    hold = 3000,
    requireReverse = true,
    limit = 15,
    visual = true,
    mapBay = true,
  }),
  createTask('return', 'finish', parkingBay.coords, 'task_return_label', 'task_return_instruction', {
    radius = 3,
    width = parkingBay.width,
    length = parkingBay.length,
    heading = parkingBay.heading,
    headingTolerance = 16,
    hold = 2000,
    limit = 15,
    visual = true,
    mapBay = true,
  }),
}

Config.Routes.bike = {
  preparationTask,
  createTask(
    'departure',
    'navigate',
    vector3(271.0, -1371.0, 30.9),
    'task_bike_departure_label',
    'task_bike_departure_instruction',
    { radius = 12, limit = 30 }
  ),
  createTask(
    'controlled_stop',
    'stop',
    vector3(235.5, -1346.5, 29.5),
    'task_bike_controlled_stop_label',
    'task_bike_controlled_stop_instruction',
    { radius = 6, hold = 2000, limit = 40, visual = true }
  ),
  createTask(
    'turn_entry',
    'navigate',
    vector3(216.5, -1410.2, 28.3),
    'task_bike_turn_entry_label',
    'task_bike_turn_entry_instruction',
    { radius = 12, limit = 40 }
  ),
  createTask(
    'turn',
    'stop',
    vector3(247.0, -1410.2, 29.8),
    'task_bike_turn_label',
    'task_bike_turn_instruction',
    { radius = 5, heading = 317, headingTolerance = 18, hold = 2000, maxSpeed = 1, limit = 15, visual = true }
  ),
  createTask('bike_park', 'park', parkingBay.coords, 'task_park_label', 'task_bike_park_instruction', {
    width = parkingBay.width,
    length = parkingBay.length,
    heading = parkingBay.heading,
    headingTolerance = 18,
    hold = 2000,
    limit = 15,
    visual = true,
    mapBay = true,
  }),
  createTask('return', 'finish', parkingBay.coords, 'task_return_label', 'task_return_instruction', {
    radius = 3,
    width = parkingBay.width,
    length = parkingBay.length,
    heading = parkingBay.heading,
    headingTolerance = 18,
    hold = 2000,
    limit = 15,
    visual = true,
    mapBay = true,
  }),
}

-- Truck parking by the fence requires a longer acceptance envelope.
local truckBay = { coords = vector3(243.731, -1415.683, 29.586), width = 3.6, length = 9.2, heading = 326.57 }
Config.Routes.truck = {
  preparationTask,
  createTask(
    'wide_exit',
    'navigate',
    vector3(271.0, -1371.0, 30.9),
    'task_truck_wide_exit_label',
    'task_truck_wide_exit_instruction',
    { radius = 17, limit = 30 }
  ),
  createTask(
    'junction_stop',
    'stop',
    vector3(235.5, -1346.5, 29.5),
    'task_truck_junction_stop_label',
    'task_truck_junction_stop_instruction',
    { radius = 9, hold = 3000, limit = 40, visual = true }
  ),
  createTask(
    'swept_turn',
    'navigate',
    vector3(216.5, -1410.2, 28.3),
    'task_truck_swept_turn_label',
    'task_truck_swept_turn_instruction',
    { radius = 18, limit = 40 }
  ),
  createTask(
    'approach',
    'navigate',
    vector3(248.4, -1408.6, truckBay.coords.z),
    'task_truck_approach_label',
    'task_truck_approach_instruction',
    { radius = 4, limit = 15 }
  ),
  createTask('truck_park', 'park', truckBay.coords, 'task_truck_park_label', 'task_truck_park_instruction', {
    width = truckBay.width,
    length = truckBay.length,
    heading = truckBay.heading,
    headingTolerance = 10,
    hold = 3000,
    requireReverse = true,
    limit = 15,
    visual = true,
    mapBay = true,
  }),
  createTask('return', 'finish', truckBay.coords, 'task_return_label', 'task_return_instruction', {
    radius = 3,
    width = truckBay.width,
    length = truckBay.length,
    heading = truckBay.heading,
    headingTolerance = 10,
    hold = 2000,
    limit = 15,
    visual = true,
    mapBay = true,
  }),
}

-- Shared road assessment between the class-specific manoeuvres.
local function roadAssessment()
  local limits = Config.SpeedLimits
  return {
    createTask(
      'give_way',
      'stop',
      vector3(-73.542, -1364.335, 27.789),
      'task_give_way_label',
      'task_give_way_instruction',
      { radius = 8, hold = 2000, limit = limits.residence, visual = true }
    ),
    createTask(
      'town',
      'navigate',
      vector3(-355.143, -1420.282, 27.868),
      'task_town_label',
      'task_town_instruction',
      { radius = 22, limit = limits.town }
    ),
    createTask(
      'on_ramp',
      'navigate',
      vector3(-453.790, -1444.726, 27.665),
      'task_on_ramp_label',
      'task_on_ramp_instruction',
      { radius = 22, limit = limits.town }
    ),
    createTask(
      'freeway_west',
      'navigate',
      vector3(-900.647, -1986.280, 26.109),
      'task_freeway_west_label',
      'task_freeway_west_instruction',
      { radius = 30, limit = limits.freeway }
    ),
    createTask(
      'freeway_east',
      'navigate',
      vector3(1225.759, -1948.792, 38.718),
      'task_freeway_east_label',
      'task_freeway_east_instruction',
      { radius = 30, limit = limits.freeway }
    ),
    createTask(
      'leave_freeway',
      'navigate',
      vector3(1163.603, -1841.771, 35.679),
      'task_leave_freeway_label',
      'task_leave_freeway_instruction',
      { radius = 24, limit = limits.town }
    ),
    createTask(
      'return_to_school',
      'navigate',
      vector3(235.283, -1398.329, 28.921),
      'task_return_to_school_label',
      'task_return_to_school_instruction',
      { radius = 18, limit = limits.residence }
    ),
  }
end
for _, routeName in ipairs({ 'car', 'bike', 'truck' }) do
  local shortRoute, fullRoute = Config.Routes[routeName], {}
  for i = 1, 4 do
    fullRoute[#fullRoute + 1] = shortRoute[i]
  end
  for _, task in ipairs(roadAssessment()) do
    fullRoute[#fullRoute + 1] = task
  end
  for i = 5, #shortRoute do
    fullRoute[#fullRoute + 1] = shortRoute[i]
  end
  Config.Routes[routeName] = fullRoute
end
