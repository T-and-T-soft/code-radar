#!/usr/bin/env sh
set -eu

REPO="${RADAR_INSTALL_REPO:-T-and-T-soft/code-radar}"
VERSION="${RADAR_INSTALL_VERSION:-latest}"
VERIFY_SIGNATURE="${RADAR_VERIFY_INSTALL_SIGNATURE:-1}"
OIDC_ISSUER="${COSIGN_OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
SIGNING_REPO="${RADAR_RELEASE_SIGNING_REPO:-T-and-T-soft/code-radar-private}"
PUBLIC_SIGNING_REPO="${RADAR_PUBLIC_RELEASE_SIGNING_REPO:-T-and-T-soft/code-radar}"
PUBLIC_SIGNING_WORKFLOW="${RADAR_PUBLIC_RELEASE_SIGNING_WORKFLOW:-sign-public-release.yml}"
DEFAULT_IDENTITY_REGEXP="https://github.com/(${SIGNING_REPO}/.github/workflows/release.yml|${PUBLIC_SIGNING_REPO}/.github/workflows/${PUBLIC_SIGNING_WORKFLOW})@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+.*"
IDENTITY_REGEXP="${COSIGN_IDENTITY_REGEXP:-$DEFAULT_IDENTITY_REGEXP}"

if [ "$VERSION" = "latest" ]; then
  URL="https://github.com/${REPO}/releases/latest/download/radar-cli-installer.sh"
else
  URL="https://github.com/${REPO}/releases/download/${VERSION}/radar-cli-installer.sh"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

download() {
  source_url="$1"
  destination="$2"
  if command -v curl >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -fsSL "$source_url" -o "$destination"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$destination" "$source_url"
  else
    echo "radar install: curl or wget is required" >&2
    exit 1
  fi
}

verify_signature() {
  artifact="$1"
  bundle="$2"
  if [ "$VERIFY_SIGNATURE" = "0" ]; then
    echo "radar install: signature verification disabled by RADAR_VERIFY_INSTALL_SIGNATURE=0" >&2
    return 0
  fi
  if ! command -v cosign >/dev/null 2>&1; then
    echo "radar install: cosign is required for signed install verification" >&2
    echo "Install cosign or set RADAR_VERIFY_INSTALL_SIGNATURE=0 to explicitly skip verification." >&2
    exit 1
  fi
  if [ ! -f "$bundle" ]; then
    echo "radar install: signature bundle not found: $bundle" >&2
    exit 1
  fi
  cosign verify-blob \
    --certificate-identity-regexp "$IDENTITY_REGEXP" \
    --certificate-oidc-issuer "$OIDC_ISSUER" \
    --bundle "$bundle" \
    "$artifact"
}

INSTALLER="$TMP_DIR/radar-cli-installer.sh"
BUNDLE="$INSTALLER.cosign.bundle"
download "$URL" "$INSTALLER"
if [ "$VERIFY_SIGNATURE" != "0" ]; then
  download "${URL}.cosign.bundle" "$BUNDLE"
fi
verify_signature "$INSTALLER" "$BUNDLE"
sh "$INSTALLER"
