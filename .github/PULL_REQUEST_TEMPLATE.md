## Summary
- What problem does this PR solve?
- What changed?

## Change Type
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor
- [ ] Documentation
- [ ] Build/CI

## API / Behavior Impact
- [ ] Additive only
- [ ] Breaking change (describe migration steps below)

## Validation
List commands run and outcomes:

```bash
lua scripts/verify-module-map.lua
lua scripts/verify-no-direct-httpget.lua
lua scripts/verify-no-direct-tweencreate.lua
lua scripts/build-bundle.lua
```

## Compatibility Checklist
- [ ] Existing loaders still work (`Main loader/*`, `feature/*`)
- [ ] Existing element contracts not regressed
- [ ] Documentation updated (`docs/API.md`, changelog if needed)
- [ ] Tests updated/added (`tests/regression/*`, `tests/smoke/*` as needed)

## Migration Notes (if breaking)
Describe required migration steps for users.
