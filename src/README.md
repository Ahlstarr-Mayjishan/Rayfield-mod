# Rayfield Src Layout

Canonical source tree for runtime + studio compatibility.

- `api/`: shared API/load layer (`client`, `cache`, `resolver`, `registry`, `loader`, `errors`)
- `core/`: lifecycle/container/constants/bootstrap/ui-state/runtime-env/window-controller/animation
- `services/`: theme/settings/config/utilities/logger/input-dispatcher
- `ui/`: window/topbar/tabs/notifications/elements
- `feature/`: drag/reorder/tabsplit/mini-window/enhanced (canonical parent is singular `feature`)
- `entry/`: canonical public entrypoints
- `legacy/`: thin forwarding helpers (non-canonical, debug should target `src/*`)

Policy:
- Business logic lives in `src/*`.
- Legacy paths in `feature/*` and `Main loader/*` are wrappers only.
- Canonical module maps are maintained in:
  - `src/api/registry.lua`
  - `src/entry/module-map.lua`
  - `src/manifest.json`

Current split status:
- `src/entry/rayfield-modified.entry.lua` is orchestration-only and forwards runtime behavior to `src/entry/rayfield-modified.runtime.lua`.
- `src/ui/elements/factory.lua` forwards to `src/ui/elements/factory/init.lua`.
- `src/ui/elements/widgets/extracted.lua` forwards to `src/ui/elements/widgets/index.lua`.
- `src/feature/drag/init.lua` forwards to `src/feature/drag/controller.lua` and keeps helper modules (`input`, `window`, `dock`, `detach-gesture`, `merge-indicator`, `cleanup`).
- `src/feature/tabsplit/init.lua` forwards to `src/feature/tabsplit/controller.lua` and keeps helper modules (`state`, `panel`, `dragdock`, `zindex`, `hover-effects`, `layout-free-drag`).
- `src/feature/enhanced/init.lua` forwards to `src/feature/enhanced/create-enhanced-rayfield.lua` with extracted class exports (`error-manager`, `garbage-collector`, `remote-protection`, `memory-leak-detector`, `profiler`).
- `src/feature/mini-window/init.lua` forwards to `src/feature/mini-window/controller.lua` with helper modules (`layout`, `drag`, `dock`).

Validation scripts:
- `scripts/verify-module-map.lua`
- `scripts/verify-no-direct-httpget.lua`
- `scripts/verify-no-direct-tweencreate.lua`
