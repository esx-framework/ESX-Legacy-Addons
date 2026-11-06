# Regression tests

These tests execute the resource with mocked Cfx, ESX, NUI and database APIs.
They cover sessions, payment, prerequisites, vehicle/driver binding, task order,
continuous holds, parking geometry, faults, licence confirmation and cleanup.
Theory fixtures check server-assigned questions, grading, malformed submissions,
retries and the original question banks in ten languages. Vehicle fixtures check
server-created leases, occupied spawns, late callbacks and safe cleanup.

From this directory:

```sh
npm ci --ignore-scripts
npm run test:server
python -m pip install lupa
python run-lua-tests.py
```

Node tests use the pinned development dependency Fengari 0.1.4. Python tests use Lupa's Lua 5.4 runtime. Set `ESX_QA_LUA_MODULE_PATH` if Lupa is installed outside Python's module search path. Both runners read the resource root one directory above `tests`; `ESX_QA_RESOURCE_ROOT` optionally selects another checkout. The Python runner also accepts that root as its first argument.

Set `ESX_QA_RATE_LIMITER` to `esx_lib/imports/rateLimiter/server.lua` from your
ESX checkout to exercise the real request limiter in the Node suite.

Coverage includes payment/session replay, ordered tasks, vehicle and driver binding, continuous holds, full parking footprint and reverse entry, four versus five errors, gradual damage cooldown, late callbacks, numeric native booleans (`1`/`0`), and float fuel initialization (`100.0`). Native marker fixtures check the marker call contract, numeric native booleans, visibility and fading distances, cached ground queries, cleanup, and the absence of added ground markings for existing parking bays. They also cover the optional route-distance readout; they do not sample or render GPS route positions. Assertions fail with a nonzero exit status.

The client fixture checks English/Spanish payloads and replacement of the
character's owned licence cache. Vector mocks retain `.w` for spawn headings.
The evaluator accepts the driving task types only; unsupported school types fail
closed. The client fixture mocks `Translate`; it does not exercise the ESX locale
loader. The tests do not open FiveM or certify map placement, physics, focus or
multiplayer behaviour.

Marker contracts are documented in [DrawMarker](https://github.com/citizenfx/natives/blob/master/GRAPHICS/DrawMarker.md) and the [Cfx marker types](https://docs.fivem.net/docs/game-references/markers/). Visibility, terrain and alignment with painted map bays still require in-game checks.

Test files and development dependencies are not loaded by the resource manifest.
Node, npm and Python are needed only to run these development checks.
