# MCP Threat Model (stdio)

## Trust boundaries

| Component | Trust level |
|-----------|-------------|
| MCP client | Trusted to invoke tools |
| `radar` process | Runs with user OS privileges |
| Scanned workspace | Untrusted code |
| External linters (eslint, ruff, clippy, dart) | Semi-trusted binaries on PATH |

## Threats and mitigations

### Policy tamper

| Threat | Mitigation |
|--------|------------|
| Client points `config_path` / org policy at attacker-controlled YAML | `radar policy validate` + `release-verify`; effective config is read-only via MCP resource |
| Disabling critical rules without audit | Org policy `forbidden_disable`; suppressions require audit path when configured |

### Audit and accountability

| Threat | Mitigation |
|--------|------------|
| Silent suppressions via MCP | `apply_suppression` appends JSONL audit entry when `policy.suppress_audit_path` is set (same schema as CLI baseline update) |
| No trace of who changed baseline | Audit `actor` field (`mcp` vs `cli`) and RFC3339 timestamp |

### Denial of service

| Threat | Mitigation |
|--------|------------|
| Huge workspace scan | Wall-clock timeout per scan; `cancel` token; concurrent scan mutex |
| Oversized MCP responses | 512KB response cap with `manifest.truncated` |
| Memory exhaustion from tool stdout | Subprocess stdout cap (default 10 MiB, configurable) |
| Scan cache growth | LRU + TTL on `scan_id` cache |

### Subprocess abuse

| Threat | Mitigation |
|--------|------------|
| Arbitrary command injection via MCP args | No shell from tool arguments; allowlisted binaries only (`process.rs`) |
| Path escape for suppressions / reads | `validate_path` sandbox under workspace root |
| Runaway external linter | Per-tool timeout + stdout cap; skipped gracefully when binary missing |

## Controls

- Path sandbox: findings and suppressions cannot escape workspace root
- Concurrent scan mutex: second scan rejected with clear error
- Response truncation at 512KB with `manifest.truncated`
- `scan_id` LRU cache with TTL (default 900s)
- No arbitrary shell from MCP tool arguments
