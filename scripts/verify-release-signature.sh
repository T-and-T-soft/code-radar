#!/usr/bin/env bash
# Verify cosign signature on a release archive + keyless bundle.
#
# Environment:
#   COSIGN_IDENTITY          Certificate identity (e.g. GitHub OIDC subject)
#   COSIGN_IDENTITY_REGEXP   Certificate identity regex for tag/branch release subjects
#   RADAR_REQUIRE_SIGNATURE  When "1", fail if cosign missing or verification skipped
#   RADAR_RELEASE_MODE       When "1", same strict behavior as RADAR_REQUIRE_SIGNATURE
#
# Usage:
#   verify-release-signature.sh /path/to/radar.tar.gz [/path/to/radar.tar.gz.cosign.bundle]
set -euo pipefail

ARTIFACT="${1:?usage: verify-release-signature.sh /path/to/artifact [bundle-or-sig]}"
SIGNATURE="${2:-${ARTIFACT}.cosign.bundle}"
LEGACY_SIG="${ARTIFACT}.sig"
LEGACY_CERT="${ARTIFACT}.pem"
COSIGN_IDENTITY="${COSIGN_IDENTITY:-}"
COSIGN_IDENTITY_REGEXP="${COSIGN_IDENTITY_REGEXP:-}"

strict() {
  [[ "${RADAR_REQUIRE_SIGNATURE:-}" == "1" || "${RADAR_RELEASE_MODE:-}" == "1" ]]
}

if ! command -v cosign >/dev/null 2>&1; then
  echo "cosign not installed" >&2
  if strict; then
    echo "RADAR_REQUIRE_SIGNATURE=1 or RADAR_RELEASE_MODE=1 requires cosign" >&2
    exit 1
  fi
  echo "Install cosign: https://docs.sigstore.dev/cosign/installation/" >&2
  exit 0
fi

if [[ ! -f "$SIGNATURE" && ! -f "$LEGACY_SIG" ]]; then
  echo "signature file not found: $SIGNATURE" >&2
  if strict; then
    exit 1
  fi
  exit 0
fi

IDENTITY_ARGS=()
if [[ -n "$COSIGN_IDENTITY_REGEXP" ]]; then
  IDENTITY_ARGS=(--certificate-identity-regexp "$COSIGN_IDENTITY_REGEXP")
elif [[ -n "$COSIGN_IDENTITY" ]]; then
  IDENTITY_ARGS=(--certificate-identity "$COSIGN_IDENTITY")
else
  echo "Set COSIGN_IDENTITY or COSIGN_IDENTITY_REGEXP to the release signing certificate identity" >&2
  if strict; then
    exit 1
  fi
  exit 0
fi

if [[ -f "$SIGNATURE" && "$SIGNATURE" == *.cosign.bundle ]]; then
  cosign verify-blob \
    "${IDENTITY_ARGS[@]}" \
    --certificate-oidc-issuer "${COSIGN_OIDC_ISSUER:-https://token.actions.githubusercontent.com}" \
    --bundle "$SIGNATURE" \
    "$ARTIFACT"
elif [[ -f "$LEGACY_SIG" && -f "$LEGACY_CERT" ]]; then
  cosign verify-blob \
    "${IDENTITY_ARGS[@]}" \
    --certificate-oidc-issuer "${COSIGN_OIDC_ISSUER:-https://token.actions.githubusercontent.com}" \
    --certificate "$LEGACY_CERT" \
    --signature "$LEGACY_SIG" \
    "$ARTIFACT"
else
  cosign verify-blob \
    "${IDENTITY_ARGS[@]}" \
    --certificate-oidc-issuer "${COSIGN_OIDC_ISSUER:-https://token.actions.githubusercontent.com}" \
    --signature "$SIGNATURE" \
    "$ARTIFACT"
fi

echo "Signature verification OK for $ARTIFACT"
