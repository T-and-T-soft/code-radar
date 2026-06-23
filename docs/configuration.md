# Configuration reference

Copy [`.radar.example.toml`](../.radar.example.toml) to `.radar.toml` in your project root.
Or run:

```bash
radar init
```

This creates `.radar.toml`, `.radarignore`, and a GitHub Actions workflow unless
the files already exist.

| Path | Purpose |
|------|---------|
| `.radar.toml` | Scan and report settings |
| `.radar/baseline.json` | Accepted finding fingerprints |
| `.radar/cache/` | Parse and tool output cache |
| `.radarignore` | Extra ignore globs ([example](../.radarignore.example)) |
| `radar-policy.yaml` | Org policy (optional) |

## Collection defaults

- **`skip_test_paths = true`** — skips `*.test.ts(x)`, `*.spec.ts(x)`, `e2e/`, `__tests__/`, fixtures, Storybook, `.d.ts`.
- **`include_vendor = false`** — skips `node_modules/`, `target/`, `dist/`, `.next/`, `.git/`, and similar trees (plus `.gitignore` / `.radarignore`).

## Scan performance (`[scan]`)

| Setting | Default | Description |
|---------|---------|-------------|
| `concurrency` | `4` | Parallel file workers and dispatch fan-out |
| `max_files` | `50000` | Max files per scan |
| `parse_cache_max_entries` | `512` | LRU tree-sitter cache |
| `scan_cache_max_entries` | `100` | MCP in-memory report cache |
| `respect_gitignore` | `true` | Honor `.gitignore` during walk |

Incremental scans: `radar scan . --since main` or MCP `since` / `since_ref`.

`radar scan` is optimized for local feedback: native slop, structure, security,
taint, rule-pack, and SCA checks run by default. The command exits `0` unless
you pass `--fail-on`; use `radar verify` for the full pre-merge quality gate.
Use `--format html` to create a shareable local report.

## Reviewed false positives (`[exclusions]`)

Use finding exclusions for reviewed false positives. Exclusions are applied in
the scan engine, so they work the same way in local CLI, MCP tools, Git hooks,
and GitHub Actions.

```toml
[[exclusions.findings]]
rule_id = "SEC-SQLI-001"
path = "src/generated/**"
reason = "Generated query builder reviewed manually"

[[exclusions.findings]]
fingerprint = "finding-fingerprint-from-json"
reason = "False positive confirmed in review"
```

Excluded findings are marked `suppressed = true`. They do not affect scorecards,
SARIF output, GitHub annotations, or `--fail-on` gates. Keep `reason` explicit so
accepted risk remains auditable.

## Slop thresholds (`[slop]`)

| Setting | Default | Description |
|---------|---------|-------------|
| `todo_per_file_threshold` | `5` | TODO/FIXME cluster threshold per source file |
| `git_size_line_threshold` | `400` | Large file/diff line threshold |
| `rename_storm_threshold` | `10` | Rename count threshold in the churn window |
| `blast_file_threshold` | `8` | Changed source files needed for diff blast-radius signal |
| `blast_bucket_threshold` | `4` | Distinct source buckets needed for diff blast-radius signal |
| `tiny_edit_file_threshold` | `8` | Tiny-edited source files needed for churn detection |
| `tiny_edit_max_lines` | `2` | Max changed lines for a file to count as a tiny edit |

## Taint (`[taint]`)

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Taint pass after AST rules |
| `max_depth` | `8` | Propagation depth |
| `cross_file` | `true` | Follow imports within workspace |

Best-effort only; not full IFDS/points-to.

## Threat model

Copy [`threat-model.example.yaml`](../threat-model.example.yaml) to `.radar/threat-model.yaml` to boost severity on sensitive paths and entry points.

## Native security rules

Regex pack and vulnerability cache refresh **in the background** when you run `radar scan`;
the current scan uses the existing cache or bundled pack so local feedback does
not block on network access. Sources: Gitleaks, GitLab SAST, opengrep;
OSSF for malware, and OSV compact dumps for offline dependency advisory
coverage. See [rules-pack.md](rules-pack.md).

```bash
radar rules status   # feed sources + cache version
```

```toml
[rules]
update = "auto"
update_feeds = "public"

[sca]
cache_update_interval_hours = 24
```

## Native SCA

Builtin dependency and malware scanning uses the local vulnerability cache only.

```toml
[sca]
cache_update_interval_hours = 24
cache_url = "https://github.com/T-and-T-soft/code-radar/releases/download/vuln-db-latest"

[sca.feeds]
malicious = true
osv = true
```

`radar scan`, MCP tools, and CI use the local cache only. Background refresh
checks the daily `vuln.radarvdb` manifest and keeps the current pack if no newer cache is
available.

→ [sca-native.md](sca-native.md)

## Optional external tools (linters)

```bash
radar doctor --install-hints
./scripts/install-optional-tools.sh
radar scan . --external-linters
```

Tools are optional; core AST, secrets, taint, native rule-pack checks, and builtin SCA run without them.

```toml
[tools]
external_linters = false
```

Set `external_linters = true` when you want Radar to call local linters during
`scan`. Keep it off for the fastest native-first loop.
