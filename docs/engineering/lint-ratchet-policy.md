# Lint Ratchet Policy

## Goal
Prevent net-new static-analysis debt on every pull request while allowing historical debt to be paid down incrementally.

## CI Gates
The CI pipeline enforces three ratchets:

1. `luacheck` ratchet
- Scope: `src`, `feature`, `Main loader`, `tests`, `scripts`
- Compares current luacheck output to `.ci/luacheck-baseline.json`
- Fails if any `file + code` count increases
- Also enforces touched-file zero-tolerance for new `E*`, and new `E033`, `W113`, `W143`

2. Complexity ratchet
- Compares current lizard metrics to `.ci/complexity-baseline.json`
- Evaluates changed Lua files
- Fails when changed files increase complexity above baseline (`fileCCN`, `maxFunctionCCN`)
- Tracks `fileNCSS` increase as warning in report

3. Global access ratchet
- Compares direct `_G` token count to `.ci/global-access-baseline.json`
- Evaluates changed Lua files
- Fails on new direct `_G` usage outside boundary prefixes:
  - `src/entry/`
  - `Main loader/`
  - `feature/`

## Baselines
Committed baseline files:
- `.ci/luacheck-baseline.json`
- `.ci/complexity-baseline.json`
- `.ci/global-access-baseline.json`

Baselines are deterministic snapshots and part of versioned CI policy.

## Baseline Update Policy
Baseline updates are restricted to explicit debt-reset changes.

Required process:
1. Open a dedicated PR for baseline reset.
2. Apply label: `debt-reset`.
3. Include rationale in PR description:
- what changed,
- why baseline moved,
- expected follow-up debt burn-down.
4. Attach regenerated debt artifacts from CI.

No feature PR should update baseline files.

## Local Regeneration Commands
From repo root:

```bash
luacheck --config .luacheckrc --codes --ranges src feature "Main loader" tests scripts > luacheck-report.txt 2>&1 || true
python -m lizard src feature "Main loader" tests scripts -l lua -X > lizard-report.xml
git ls-files '*.lua' > all-lua-files.txt

lua scripts/ci-luacheck-ratchet.lua --write-baseline luacheck-report.txt .ci/luacheck-baseline.json
lua scripts/ci-complexity-ratchet.lua --write-baseline lizard-report.xml .ci/complexity-baseline.json
lua scripts/ci-global-access-ratchet.lua --write-baseline all-lua-files.txt .ci/global-access-baseline.json
```

## Artifacts
Each PR uploads debt artifacts:
- `luacheck-debt-report`
- `complexity-debt-report`
- `global-access-debt-report`

These artifacts are the source of truth for debt deltas per PR.
