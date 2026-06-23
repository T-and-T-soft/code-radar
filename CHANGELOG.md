# Changelog

All notable changes to Code Radar are documented here.

## [Unreleased]

### Added

- **Native security rule pack** — auto-update **directly from public feeds** (Gitleaks MIT, GitLab SAST rules MIT, Aikido opengrep-rules MIT); cached locally; `rules/pack/` in repo is offline/dev fallback only.
- `rules/pack/SOURCES.md` — upstream licenses and update paths for native rule feeds.
- Default `radar scan` runs **Security** mode with native pack + `SEC-*` AST.
- `radar verify` and MCP `run_quality_gate` — multi-phase pre-PR pipeline.
- Security rules `SEC-AUTH-001`, `SEC-ERROR-001`, `SEC-CSP-001`.
- OWASP-aligned security checklist in verification reports.
- `docs/mcp.md`, `docs/configuration.md`, `CONTRIBUTING.md`, `LICENSE`.
- **`radar-vuln`** — builtin SQLite SCA (`rules/vuln-db/vuln.db.zst`) with automatic compact-cache refresh and `radar vuln-db status`.
- **`SCA-MALWARE-*`** rule prefix for malicious-package findings (separate from `SCA-{CVE}`).

### Changed

- Native SCA uses one local cache for dependency advisories and malware checks across CLI, MCP, and CI.
- Heavy feed ingestion moved to a daily GitHub Actions cache builder; scans never call upstream vulnerability feeds.
- Vulnerability DB refresh is automatic in product flows.

### Fixed

- UTF-8 safe string slicing in SOLID SRP analysis and secret redaction (no panic on non-ASCII source).

## [0.1.0] — TBD

Initial public release: MCP stdio, 40 rules, SARIF, baseline, cargo-dist binaries.

[Unreleased]: https://github.com/T-and-T-soft/code-radar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/T-and-T-soft/code-radar/releases/tag/v0.1.0
