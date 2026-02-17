# Module Boundaries

## Canonical Rule

All production logic lives under `src/*`.
Legacy files under `feature/*` and `Main loader/*` are wrappers only.

## Layering

1. `src/api/*`
- Runtime loading, cache, registry, resolver.
- Public contract for module path resolution.

2. `src/core/*`
- Lifecycle, container, constants, runtime environment, window orchestration controller.

3. `src/services/*`
- Theme/settings/config/utilities/logger/input dispatcher.

4. `src/ui/*`
- Window/topbar/tabs/notifications/elements modules.
- `src/ui/elements/factory/init.lua` is canonical elements factory entry.

5. `src/feature/*`
- Feature domains: drag, tabsplit, mini-window, reorder, enhanced.
- `init.lua` in each domain is the public coordinator.

6. `src/entry/*`
- Public entrypoints.
- `rayfield-modified.entry.lua` is orchestration-only.
- `rayfield-modified.runtime.lua` keeps runtime behavior.

7. `src/legacy/*`
- Internal compatibility forwarders and wrapper map.

## Compatibility

- Registry source of truth: `src/api/registry.lua`.
- Entry module map: `src/entry/module-map.lua`.
- Manifest of canonical modules: `src/manifest.json`.

## Validation

- `scripts/verify-module-map.lua` validates mapping consistency.
- `scripts/verify-no-direct-httpget.lua` detects prohibited direct HTTP calls.