# Contributing

Thanks for contributing to Rayfield Mod.

## Scope
- Canonical source lives in `src/`.
- Loader compatibility layers live in `Main loader/` and `feature/`.
- Tests and verification live in `tests/` and `scripts/`.

## Prerequisites
- Git
- Lua 5.4 CLI (`lua`, `luac`)

## Local Validation
Run these before opening a PR:

```bash
lua scripts/verify-module-map.lua
lua scripts/verify-no-direct-httpget.lua
lua scripts/verify-no-direct-tweencreate.lua
lua scripts/build-bundle.lua
```

Install local pre-push hooks once:

```bash
bash scripts/install-hooks.sh
```

Optional lint/format checks:

```bash
luacheck --config .luacheckrc --codes --ranges scripts
selene src
stylua --check .
lizard src -l lua -C 30 -L 220
```

CI runs Selene/StyLua on changed Lua files to avoid blocking unrelated legacy formatting debt.
Use full-repo checks locally when you are doing cleanup work.

CI runs the complexity report in advisory mode by default. Set repository variable `STRICT_COMPLEXITY_GUARD=true` to make complexity thresholds blocking.
When luacheck fails in CI, download artifact `luacheck-context` to get full-file context for each reported file.
GitHub Pages deploy is opt-in. Set repository variable `ENABLE_GH_PAGES=true` after configuring Pages in repository settings.

Optional syntax pass:

```bash
find . -name "*.lua" -not -path "./.git/*" -exec luac -p {} \;
```

## Coding Rules
- Keep behavior additive unless a breaking change is explicitly planned.
- Do not bypass API client boundaries with direct `HttpGet` in runtime modules.
- Do not bypass animation wrapper with direct `TweenService:Create` where project rules disallow it.
- Keep loader/runtime compatibility with executor environments (`loadstring`, `game:HttpGet`).
- Update docs for public API changes in `Documentation/API.md`.
- Add or update smoke/regression coverage when adding element contracts.

## Pull Requests
- Use focused PRs (one feature/fix group per PR).
- Include:
  - Problem statement
  - What changed
  - Risk / compatibility impact
  - Test evidence (commands and results)
- If build outputs are affected, include generated artifacts in the same PR.
- By contributing, you agree to `CLA.md`.

## Release Process
- Update user-facing docs (`Documentation/API.md`, examples, changelog) in the same PR.
- Run local validation and ensure CI is green on `main`.
- Tag releases using semantic version tags (`vMAJOR.MINOR.PATCH`).
- Keep release notes clear about behavioral changes and migration impact.

## Versioning Strategy
- This project uses Semantic Versioning:
  - `MAJOR`: breaking API/behavior changes
  - `MINOR`: backward-compatible features
  - `PATCH`: backward-compatible fixes

## Breaking Change Policy
- Breaking changes must be explicitly marked in PR title/body.
- Include migration notes in `Documentation/CHANGELOG.md`.
- Preserve loader compatibility when possible; if not possible, document exact impact and fallback path.

## Branch Protection (Maintainers)
Enable GitHub branch protection on `main` with:
- Require pull request before merging
- Require approvals (at least 1)
- Require review from Code Owners
- Require branches to be up to date before merging
- Required checks:
  - `Lua Syntax Check`
  - `Run Verification Scripts`
  - `Luacheck Lint`
  - `Selene Lint`
  - `Complexity Report`
  - `StyLua Format Check`
  - `Build Production Bundle`
  - `PR Metadata Guard`
  - `Changed Files Guard`

## Commit Guidance
- Prefer short, imperative commit subjects.
- Keep unrelated refactors out of feature commits.

## Security
- Do not post exploit details or sensitive bypass chains in public issues.
- Report vulnerabilities via the process in `SECURITY.md`.
