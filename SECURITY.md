# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| 0.x     | :x:                |

## Reporting a Vulnerability

Report security issues privately to the maintainers via GitHub Security Advisories on this repository, or email the security contact listed in the repository settings.

Please include:

- Affected component (`radar-cli`, `radar-mcp`, rule pack, or CI action)
- Steps to reproduce
- Impact assessment (data exposure, RCE, sandbox escape)

We aim to acknowledge reports within **3 business days** and provide a fix timeline within **14 days** for confirmed high/critical issues.

## Scope

Code Radar runs locally with subprocess access to configured linters and SCA tools. In scope:

- Path sandbox escapes (`workspace_root` validation)
- MCP stdio handler panics or unbounded output
- Policy bypass (disabling `forbidden_disable` rules)
- Secret leakage in reports or logs

Out of scope:

- Findings in scanned application source code (use inline suppression or baseline)
- Vulnerabilities in third-party linters (eslint, ruff, clippy, dart, etc.)

## Secure Defaults

- Org policy can forbid disabling critical rules (`SEC-SECRET-001`, etc.)
- `RADAR_OFFLINE=1` disables network-oriented subprocess flags
- Release archives should be verified with `scripts/verify-release-signature.sh` (cosign)
- Release integrity and optional native signing are documented in `docs/release-signing.md`

## Disclosure

We follow coordinated disclosure. Credit will be given in release notes unless you request anonymity.
