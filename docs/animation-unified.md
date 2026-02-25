# Unified Animation Layer

## Goal

Rayfield now uses one shared animation runtime so base UI, feature modules, and enhanced APIs run on the same tween/text lifecycle engine.

## Canonical Modules

- `src/core/animation/engine.lua`
- `src/core/animation/public.lua`
- `src/core/animation/sequence.lua`
- `src/core/animation/ui.lua`
- `src/core/animation/text.lua`
- `src/core/animation/easing.lua`
- `src/core/animation/cleanup.lua`

## Public Surface

- `Rayfield.Animate(object, tweenInfo?, goals?)`
- `Rayfield.Animate.Create(object, tweenInfo, goals, opts?)`
- `Rayfield.Animate.Play(object, tweenInfo, goals, opts?)`
- `Rayfield.Animate.UI(object)`
- `Rayfield.Animate.Text(textObject)`
- `Rayfield:GetAnimationEngine()`

## Compatibility

- Backward-compat animation bridge (`RayfieldAdvanced.AnimationAPI.new()`) has been removed from canonical flow.
- Canonical animation entrypoint is now `Rayfield.Animate`.

## Migration Rule

- Do not call `TweenService:Create` directly in canonical modules.
- Use shared animation object:
  - runtime-level: `Animation:Create(...)`
  - module-level: `self.Animation:Create(...)`

## Lifecycle Behavior

- Active tween tracking is centralized.
- Text loop effects are stopped when:
  - target object is destroyed
  - target object is not visible in ancestor chain
  - main UI is hidden/minimized
  - Rayfield is destroyed
