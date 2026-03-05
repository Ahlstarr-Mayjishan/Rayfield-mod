# Runtime Config v2 Migration

## Summary
Runtime behavior now uses explicit runtime configuration instead of implicit internal reads from `_G.__RAYFIELD_*` inside service modules.

New public APIs:
- `Rayfield:ConfigureRuntime(optionsTable)`
- `Rayfield:GetRuntimeConfig()`

## What Changed
1. Internal services (`src/api/client.lua`, `src/services/http-loader.lua`, `src/services/compatibility.lua`) no longer read runtime flags directly from `_G.__RAYFIELD_*`.
2. Loader boundary files (`src/entry/*`, `Main loader/*`, `feature/*`) now pass runtime options into runtime config explicitly.
3. Runtime config is now queryable at runtime via `GetRuntimeConfig()`.

## Before
Behavior was controlled by mutating globals and relying on implicit reads in internal modules:

```lua
_G.__RAYFIELD_RUNTIME_ROOT_URL = "https://raw.githubusercontent.com/org/repo/main/"
_G.__RAYFIELD_HTTP_TIMEOUT_SEC = 45
_G.__RAYFIELD_HTTP_CANCEL_ON_TIMEOUT = true
```

## After
Use explicit runtime API once Rayfield is initialized:

```lua
local ok, status = Rayfield:ConfigureRuntime({
	runtimeRootUrl = "https://raw.githubusercontent.com/org/repo/main/",
	httpTimeoutSec = 45,
	httpCancelOnTimeout = true,
	httpDefaultCancelOnTimeout = true,
	execPolicy = {
		mode = "auto",
		escalateAfter = 2,
		windowSec = 90
	}
})
```

Inspect active runtime config:

```lua
local current = Rayfield:GetRuntimeConfig()
print(current.runtimeRootUrl, current.httpTimeoutSec)
```

## Compatibility Notes
1. Loader boundary still accepts legacy `_G.__RAYFIELD_*` inputs.
2. Those globals are translated at bootstrap time into explicit runtime config.
3. Internal modules should not add new direct `_G.__RAYFIELD_*` reads.

## Recommended Migration Sequence
1. Keep existing global flags in bootstrap temporarily.
2. Move settings into `Rayfield:ConfigureRuntime(...)`.
3. Remove direct global mutation from call sites after verification.
