# Code Radar MCP Server

Code Radar exposes a **stdio** MCP server for MCP-compatible clients. Use it as
a local quality gate for repository changes: Radar checks security risk,
slop, structure/code-health drift, and dependency risk before merge. One
binary handles both CLI and MCP:

```bash
radar mcp
```

## Install

Install Code Radar into a supported MCP client:

```bash
radar mcp install codex
radar mcp install claude
radar mcp install cursor
radar mcp doctor
```

`install` updates the MCP client config with the current `radar` binary path.
`doctor` prints the detected config locations and which clients are already
configured.

Manual config is still available when you need to manage the file yourself:

```json
{
  "mcpServers": {
    "code-radar": {
      "command": "/usr/local/bin/radar",
      "args": ["mcp"],
      "env": {
        "RUST_LOG": "radar=info"
      }
    }
  }
}
```

Build from source:

```bash
RADAR_LICENSE_API_URL=https://zfwbcqpplompjuonilef.supabase.co/functions/v1 \
RADAR_LICENSE_PUBLIC_KEY=SiOqE4XgwSDt5OArtLhdQS0GFfEC4NUXnrcaB9lgqZw= \
cargo build --release -p radar-cli
# use ./target/release/radar in mcp.json
```

`radar mcp doctor` reports whether the current binary has the license API URL
and entitlement verification key configured. Production MCP tools fail closed
when either value is missing.

## Licensing

Production release builds require a signed Code Radar entitlement before MCP
scan, repair, suppression, or quality-gate tools run. MCP uses the same local
activation cache as the CLI:

```bash
radar activate RADAR-XXXXXX-XXXXXX-XXXXXX-XXXXXX
radar license status
radar mcp install all
```

Do not put long-lived license keys directly into `mcp.json`. Use `radar
activate` locally, or pass `RADAR_LICENSE_KEY` only in controlled CI/automation
contexts. See [Licensing](licensing.md).

## Recommended workflow

1. Make the change.
2. **`scan_project_summary`** — quick native slop/security/code-health summary; note `scan_id`.
3. **`get_recommendations`** — pass `scan_id` to avoid re-scanning.
4. **`explain_finding`** — blueprint for a specific `finding_id` (fingerprint).
5. **`security_diff_scan`** — only changed files vs `since_ref` (e.g. `main`) before a PR.
6. **`run_quality_gate`** — build → types → lint → tests → security → diff (exit semantics in CLI `radar verify`).

## Tools

| Tool | Purpose |
|------|---------|
| `scan_project_summary` | Merge-readiness signals: slop, security, code-health + `inventory` |
| `get_file_insights` | Single-file findings and recommendations |
| `scan_security_full` | Secrets, SAST, taint, SCA |
| `security_diff_scan` | Security scan on git-diff changed paths |
| `get_recommendations` | Prioritized fix plan (`domain`: all, slop, security, code_health) |
| `explain_finding` | Detailed remediation for one fingerprint |
| `apply_suppression` | Inline disable comment or baseline entry |
| `run_quality_gate` | Multi-phase verification report (JSON) |
| `radar_doctor` | Tooling and grammar diagnostics |
| `list_scan_ids` | Recent cached scan IDs |

## Resources

| URI | Content |
|-----|---------|
| `radar://config/effective` | Merged `.radar.toml` + org policy (JSON) |
| `radar://report/{scan_id}` | Cached scan report (JSON, may truncate at 512KB) |
| `radar://report/{scan_id}/cbor` | Same report as CBOR (`--features cbor` on `radar-mcp`) |

## Limits and safety

- **512KB** max JSON response; `manifest.truncated` when capped.
- **300s** default scan timeout per tool invocation.
- **One concurrent scan** per MCP process (second call returns a clear error).
- Path arguments are sandboxed under `workspace_root`.
- See [security/mcp-threat-model.md](security/mcp-threat-model.md).

## Schema

Report JSON validates against [schemas/inspector-report-1.0.json](schemas/inspector-report-1.0.json).
