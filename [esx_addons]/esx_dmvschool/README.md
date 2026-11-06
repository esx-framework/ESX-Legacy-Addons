# esx_dmvschool

Driving theory and practical examinations for cars, motorcycles and trucks.

The practical combines urban and highway driving with a controlled stop and a
vehicle-specific parking manoeuvre. Native objective markers identify the
current task from a distance, with a neutral ground marker for stops. The normal
GPS blip remains available. The player performs the braking, steering and
reversing; the resource does not position the vehicle to complete a manoeuvre.

Parking and finish tasks use the existing spaces at the school. Their configured
position, orientation and vehicle footprint determine acceptance. Car and
motorcycle use the smaller bay beside the starting area; the truck parks beside
the fence with its cab toward the aisle.

## Requirements and installation

- ESX Legacy 1.16.3 with `esx_lib`
- `esx_license`, `esx_textui`, `oxmysql` and OneSync
- An FXServer artifact with `serverEntityCreated` support for spawn clearance

Start the database, ESX core and `esx_license` before `esx_dmvschool`. The license
catalog is prepared additively. Existing `dmv`, `drive`, `drive_bike` and
`drive_truck` ownership is preserved.

```cfg
setr esx:locale "es"
ensure oxmysql
ensure esx_lib
ensure es_extended
ensure esx_license
ensure esx_textui
ensure esx_dmvschool
```

The example lists the dependencies relevant to this school. English fallback
follows the framework locale settings. Original ESX question banks are retained.

## Examinations

The server selects ten different questions and requires five correct answers.
Answers are graded on the server; the client receives corrections after
submission so failed answers can be reviewed. Completing theory unlocks the
three practical examinations.

Press E at the school to open the menu. The assigned vehicle is prepared after
the server binds it to the driver. Once preparation finishes, use the normal
vehicle controls.

Each practical has fourteen tasks, an examiner in supported passenger vehicles,
an urban section, a highway section, a stop and a final manoeuvre:

- Car: reverse into a bay, align the entire vehicle and remain stopped.
- Motorcycle: perform a slow turn and park in the indicated car-park space.
- Truck: reverse into a wider and longer bay, allowing room for its bodywork.

The compact driving display uses the theory test's numeric counter and segmented
progress. The counter and faults stay above the instruction; the progress strip
sits below it. The header separates the school name from its location on two
lines when the configured title includes the translated school label.
Task titles and instructions slide when the current step changes;
telemetry updates preserve the slide. Fault slots fill with crosses, with the
failure threshold shown in red. Reduced-motion preferences disable transitions.
The display also shows distance and the applicable speed limit. Parking feedback
indicates when to enter the bay, align, stop or reverse. The holding timer resets
when the required conditions are interrupted.

Five faults fail the examination; four may still pass. By default a continuous
speeding episode counts once after 2.5 seconds above the limit plus a 5 km/h
tolerance. Damage uses a configurable body-health threshold and cooldown. The
resource does not determine blame for traffic collisions or automatically grade
ambient traffic lights.

Payment and prerequisites are checked on the server. Examination vehicles are
created by the server and leased to one session. Practical progression is bound
to that vehicle, driver, ordered tasks and server-observed movement.
Spawn clearance uses live positions and routing buckets from a vehicle registry
maintained by entity creation and removal events.
The server compares displacement with observed speed and elapsed time across the
whole route. Implausible movement blocks progression. An interruption clears
the current hold and reverse entry evidence. A sustained movement rejection
ends the attempt and releases the exam vehicle.
School callbacks and network events share a per-player `esx_lib` request limit.
Keep `esx_license:addLicense` restricted to server-side `TriggerEvent` calls.
The license is shown as confirmed only after `esx_license` reports ownership.

## Configuration and migration

Back up your existing resource and configuration before replacing them. The
rebuild uses declarative `Config.Licenses` and `Config.Routes`; existing custom
`Config.CheckPoints[].Action` functions must be converted to tasks. The default
license identifiers, prices, models, school location and question threshold are
preserved. This is a configuration-format change.

The old `:addLicense` event is removed. External integrations must not submit a
score or grant a licence to complete an examination. The resource's callbacks
validate the paid session, grade submitted answers and confirm licence ownership.

When updating an already running installation, run `refresh` before restarting
the resource so FiveM loads the new manifest and shared scripts.

`Config.School` controls the office, return position, blip and examiner model.
`Config.Licenses` controls prices, prerequisites, vehicle models, spawns and routes.
Office, return and spawn positions use `vector4(x, y, z, heading)`; task positions
use `vector3(x, y, z)`. Read a vector4 heading through `.w`.
`Config.MaxErrors`, `ExamTimeout`, `SpeedTolerance`, `SpeedingGrace`,
`DamageThreshold`, `DamageCooldown` and `AbandonTimeout` control the exam rules.
`Config.SpeedLimits` defines the residential, urban and highway defaults.

`Config.Markers` controls the native objective markers. Set
`Config.Markers.enabled = false` to hide them. The default `drawDistance` is
250 metres, with `detailDistance = 65.0`, `fadeDistance = 35.0` and
`groundInterval = 1000` milliseconds. These settings affect presentation only;
marker visibility also depends on the scene and lighting.

Set `mapBay = true` on parking and finish tasks to use the existing car-park
markings without drawing an additional ground outline. Each vehicle class has
its own acceptance dimensions. Adjust the bay and configured vehicle footprint
when changing maps or models. Parking and confirmation share a target and
orientation so the vehicle can remain stationary.

```lua
{
  id = 'reverse_park', type = 'park',
  pos = vector3(237.577, -1411.856, 29.586),
  label = 'task_park_label',
  instruction = 'task_car_reverse_park_instruction',
  width = 3.2, length = 4.6, heading = 326.43,
  headingTolerance = 16, hold = 3000,
  requireReverse = true, limit = 15, visual = true, mapBay = true
}
```

Times are milliseconds. Speeds use the configured multiplier and unit. Parking
dimensions are metres; heading follows GTA degrees. Set safe dimensions and
locations for each model. Validate your custom route inside FiveM, including any
map replacements. The server uses conservative configured vehicle dimensions;
the client additionally uses the model's real bounding box. `dimensions.offset`
optionally supplies the model box's local XY centre to the server evaluator.
Car and motorcycle remain in the same bay during the final confirmation task.
The truck also remains stationary for confirmation. Manoeuvre distance uses
horizontal separation from the parking target; GPS distance is reserved for
driving tasks. Alignment feedback can indicate a left or right turn without
changing any acceptance conditions.

Display text belongs in `locales/<language>.lua`, which returns a translation
table. Configured title, licence label and task text fields contain locale keys,
resolved with ESX `Translate`. Locale files are packaged as files, rather than
executed as shared scripts, for the ESX lazy loader. Its English fallback follows
`esx:localeFallback`; new text is provided in English and Spanish. Regional
Spanish/English codes select their base language, while `zh-cn` is retained.
Question banks live in `server/questions/<language>.lua` and are loaded only on
the server. Each question has an identifier, text, four answers and a zero-based
`correct` index. Keep answer keys out of NUI files and client payloads.

Network events and callbacks use the resource-name prefix, normally
`esx_dmvschool:*`. `IsExamActive(playerId)` on the server and `HasActiveExam` on
the client report whether an examination, payment or licence grant is active.

## Development checks

See [tests/README.md](tests/README.md) for the regression suite. Node and Python
are needed only for development checks. Test custom routes in FiveM to verify
terrain, map markings, vehicle handling, focus and multiplayer behaviour.

## License

GPL-3.0-only. Bundled Poppins and icon notices are in `html/assets`.
