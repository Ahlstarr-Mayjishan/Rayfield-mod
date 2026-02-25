# Security Policy

## Supported Versions

Security fixes are prioritized for the latest code lines:

| Version/Branch | Supported |
| --- | --- |
| `main` | Yes |
| `develop` | Best effort |
| Older tags/commits | No |

## Reporting a Vulnerability

Please do not open public issues for security vulnerabilities.

Use one of these channels:
- GitHub Security Advisories (preferred): open a private report in the repository "Security" tab.
- If advisories are unavailable, contact the maintainers directly and include:
  - Affected files/modules
  - Reproduction steps
  - Impact assessment
  - Suggested fix (if available)

## What to Include

- Environment (executor/runtime assumptions)
- Exact loader/module URL and commit/tag
- Minimal PoC
- Whether impact is:
  - Integrity (tampering)
  - Confidentiality (data exposure)
  - Availability (crash/freeze/DoS)

## Disclosure Process

- Initial triage target: within 7 days.
- If accepted, maintainers will coordinate a fix and release note.
- Public disclosure should wait until a patch is published.

## Out of Scope

- Issues caused solely by third-party executors outside this codebase.
- Missing hardening in intentionally unsupported environments.

## Malware Policy

- Maintainers do not intentionally ship malicious code.
- If you detect suspicious behavior (credential theft, hidden remote execution, silent persistence), report privately via the process above.
- Include exact loader URL, commit SHA, and reproduction steps to speed triage.
