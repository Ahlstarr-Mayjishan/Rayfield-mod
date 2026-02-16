# Changelog

## 2026-02-16

### Added
- Officialized `AnimationAPI:GetActiveAnimationCount()` for runtime visibility of live tweens.
- Added `AnimationAPI:Sequence(guiObject)` for chaining animation steps.

### Changed
- Bumped `RayfieldAdvanced.Version` from `1.0.0` to `1.1.0`.
- Hardened `test-animation-api.lua` to load advanced module from a commit-pinned raw URL.
- Added preflight checks in `test-animation-api.lua` to fail fast on stale/wrong artifacts.
- Improved Test 1 timing checks with `waitUntil(...)` to reduce false negatives on slower executors.
- Updated all-in-one cache keying from `name` to `name|url` to prevent stale module reuse across URL changes.
- Updated all-in-one auto-exec return strategy:
  - default first-run return is now lightweight loader table
  - exported UI remains accessible via `_G.Rayfield` and `_G.RayfieldUI`
  - configurable via `autoExecuteReturn = "loader" | "ui" | "none"`.

### Fixed
- Fixed animation collision risk by keying active tween tracking by `Instance` instead of `tostring(guiObject)`.
- Added deterministic animation cleanup on object removal/destruction (`AncestryChanged` + `Destroying` hooks).
- Optimized `AnimationAPI:Pulse()` to use a single repeat/reverse tween cycle instead of chained bounce spawning.
- Restored full startup animation pipeline in `CreateWindow` so loading intro transitions cleanly into the main UI.
- Fixed loading overlay persistence by explicitly finalizing startup visibility state (`LoadingFrame` hidden, `Topbar`/`TabList`/`Elements` visible).
- Fixed `UIState` topbar reference bug (`self.Main.self.Topbar` -> `self.Topbar`) in hide/unhide transitions.
- Fixed `UIState` drag-bar dependency usage by injecting `dragBar`, `dragOffset`, and `dragOffsetMobile` via init context.

## 2026-02-15

### Fixed
- Updated exploiter runtime module URLs to the correct GitHub repo owner/path.
- Added shared `MODULE_BASE_URL` usage in `Main loader/rayfield-modified.lua`.
- Fixed all-in-one URL mapping for:
  - `Main loader/rayfield-modified.lua`
  - `feature/rayfield-enhanced.lua`
  - `feature/rayfield-advanced-features.lua`
- Fixed minimized-state handling in elements modules by injecting `getMinimised`.
- Stabilized `Tab:Clear()` flow against concurrent tracking modifications.
- Added lifecycle cleanup for `MemoryLeakDetector`:
  - `stopMonitoring()`
  - `destroy()`
  - cleanup on shutdown and explicit `Rayfield:Destroy()`.

### Notes
- These changes target executor/exploiter runtime reliability.
- Studio-only flow remains secondary.
