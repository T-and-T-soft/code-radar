# Release Integrity

Code Radar release artifacts use a free default integrity path:

1. SHA256 checksums for release archives.
2. Cosign keyless signatures through GitHub OIDC.
3. Optional GitHub artifact attestations.
4. SBOM artifact plus checksum.

Native Apple Developer ID notarization and Windows Authenticode signing are
future-ready but disabled by default because they require paid certificates.

## Required Repository Variables

| Name | Purpose |
| --- | --- |
| `RADAR_LICENSE_API_URL` | Compile-time production license API URL. |
| `RADAR_LICENSE_PUBLIC_KEY` | Compile-time production entitlement verification key. |

Current production values:

```env
RADAR_LICENSE_API_URL=https://zfwbcqpplompjuonilef.supabase.co/functions/v1
RADAR_LICENSE_PUBLIC_KEY=SiOqE4XgwSDt5OArtLhdQS0GFfEC4NUXnrcaB9lgqZw=
```

Current entitlement key id:

```env
RADAR_ENTITLEMENT_KEY_ID=ed25519-1781375161
```

## Optional Repository Variables

| Name | Purpose |
| --- | --- |
| `RADAR_ATTEST_PROVENANCE` | Set to `true` to publish GitHub artifact attestations. |
| `RADAR_UPDATE_PUBLIC_KEY` | Optional base64 Ed25519 update verification key. When present, `radar update install` requires each selected asset to include a valid signature. |
| `RADAR_NATIVE_SIGNING` | Set to `true` to enable paid native macOS/Windows signing. |
| `WINDOWS_TIMESTAMP_URL` | Optional RFC 3161 timestamp URL. Defaults to `http://timestamp.digicert.com`. |
| `RADAR_RELEASE_IDENTITY_REGEXP` | Expected cosign identity for release-promotion validation. |

## Free Signing Path

The release workflow signs each archive, installer script, update manifest, and
`SHA256SUMS` with cosign keyless signing. This uses GitHub OIDC, so no private
signing key or signing secret is stored in the repository.

Release assets include:

- `*.tar.gz`, `*.zip`, `*.txz`, or `*.tgz`
- `radar-cli-installer.sh`
- `radar-cli-installer.ps1`
- `SHA256SUMS`
- `*.cosign.bundle`
- `radar-update.json`
- `radar-cli.cdx.json`
- `radar-cli.cdx.json.sha256`

Verify a release archive:

```bash
export COSIGN_IDENTITY="https://github.com/<owner>/<repo>/.github/workflows/release.yml@refs/tags/<tag>"
./scripts/verify-release-signature.sh ./radar-<target>.tar.gz
shasum -a 256 --check SHA256SUMS
```

Public promotion validates the artifact set before upload:

```bash
export RADAR_RELEASE_IDENTITY_REGEXP="https://github.com/<owner>/<repo>/.github/workflows/release.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+.*"
bash scripts/validate-public-release-assets.sh ./artifacts
```

The public distribution repository should distribute the private release
signatures. It should not blindly re-sign assets after upload.

For GitHub artifact attestations, enable `RADAR_ATTEST_PROVENANCE=true` and
verify online with:

```bash
gh attestation verify ./radar-<target>.tar.gz -R <owner>/<repo>
```

## CLI Self-Update Manifest

`radar update` does not execute downloaded shell or PowerShell scripts. It reads
a signed/checksummed JSON manifest, downloads the asset for the current target,
verifies the archive checksum, extracts the `radar` binary, then atomically
replaces the current executable. Windows uses a temporary helper copy because an
active `.exe` cannot replace itself. Successful installs leave a `.old` binary
next to the active executable so `radar update rollback` can restore the
previous version.

Default manifest URL:

```txt
https://github.com/T-and-T-soft/code-radar/releases/latest/download/radar-update.json
```

Override for testing or private channels:

```bash
RADAR_UPDATE_MANIFEST_URL=https://example.com/radar-update.json radar update check
radar update install --manifest-url https://example.com/radar-update.json
```

Manifest shape:

```json
{
  "version": "0.1.4",
  "channel": "stable",
  "notes_url": "https://github.com/T-and-T-soft/code-radar/releases/tag/v0.1.4",
  "assets": [
    {
      "target": "aarch64-apple-darwin",
      "url": "https://github.com/T-and-T-soft/code-radar/releases/download/v0.1.4/radar-aarch64-apple-darwin.tar.gz",
      "sha256": "<archive sha256 hex>",
      "format": "tar-gz",
      "binary_path": "radar",
      "signature": "<optional base64 ed25519 signature>"
    }
  ]
}
```

The signature payload is UTF-8 text:

```txt
radar-update-v1
version=<version>
target=<target>
url=<url>
sha256=<lowercase-sha256>
```

If `RADAR_UPDATE_PUBLIC_KEY` is configured in the release binary or runtime
environment, `signature` is mandatory and must verify with that Ed25519 public
key. Without the key, updater integrity is checksum-only.

`radar update install` is disabled in CI by default. GitHub Actions should pin
or select the action/runtime version instead of self-mutating a runner during a
job. Use `--allow-ci` only for controlled release automation.

## Optional Native macOS Signing

Set `RADAR_NATIVE_SIGNING=true` and add these secrets:

| Name | Purpose |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Base64 encoded Developer ID Application `.p12` certificate. |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the `.p12` certificate. |
| `MACOS_CODESIGN_IDENTITY` | Full Developer ID Application identity name. |
| `APPLE_ID` | Apple ID used by `notarytool`. |
| `APPLE_TEAM_ID` | Apple Developer Team ID. |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for notarization. |

macOS release archives are unpacked, Mach-O executables are signed with hardened
runtime and timestamping, then the payload is submitted to Apple notarization.
For the current CLI archive format there is no stapling target. If future
releases add `.app`, `.pkg`, or `.dmg` artifacts, the script staples `.pkg` and
`.dmg` outputs after notarization.

## Optional Native Windows Signing

Set `RADAR_NATIVE_SIGNING=true` and add these secrets:

| Name | Purpose |
| --- | --- |
| `WINDOWS_CODESIGN_PFX_BASE64` | Base64 encoded Authenticode `.pfx` certificate. |
| `WINDOWS_CODESIGN_PFX_PASSWORD` | Password for the `.pfx` certificate. |

Windows release archives are unpacked, `.exe`, `.dll`, and `.msi` payloads are
signed with SHA256 and an RFC 3161 timestamp, verified with `signtool`, then
repacked.

## Local Validation

Validate workflow syntax:

```bash
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/release.yml'); puts 'ok'"
```

Validate shell script syntax:

```bash
bash -n scripts/release-sign-macos.sh
bash -n scripts/verify-release-signature.sh
```

Validate PowerShell syntax on a machine with PowerShell:

```powershell
pwsh -NoProfile -Command { $null = [scriptblock]::Create((Get-Content scripts/release-sign-windows.ps1 -Raw)); 'ok' }
```
