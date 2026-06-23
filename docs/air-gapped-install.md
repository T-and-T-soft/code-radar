# Air-Gapped Installation

## Environment

```bash
export RADAR_OFFLINE=1
```

Or in `.radar.toml`:

```toml
[offline]
enabled = true
```

## Behavior

- Background rules-pack and vulnerability-pack downloads are disabled
- External linter dispatch is skipped
- Dependency advisory checks use the local vulnerability cache
- Malware checks use the same local vulnerability cache
- No scan-time call is made to OSV.dev, OSSF, npm, PyPI, Go, or other upstream vulnerability feeds

## Offline bundle

1. Copy `radar` release binary + `rules/` directory
2. Copy the latest published `vuln.radarvdb/` pack into the target cache path, or use the pack bundled into the release binary
3. Copy `radar-policy.example.yaml` and org policy
4. Run `RADAR_OFFLINE=1 radar doctor --json` to validate

`RADAR_OFFLINE=1` only disables scan-time dependency and rules feed network
access. Production licensing still requires online validation against the
license server; paid commands fail closed when validation is unavailable. See
[Licensing](licensing.md).
