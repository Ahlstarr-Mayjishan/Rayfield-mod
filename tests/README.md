# Tests Layout

Canonical test scripts are organized by purpose:

- `smoke/`: basic runtime sanity checks
- `regression/`: feature-specific regression tests
- `helpers/`: shared test helper modules

Root test files (`rayfield-smoke-test.lua`, `test-animation-api.lua`) forward to canonical `tests/*` scripts.
