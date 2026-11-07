#!/usr/bin/env bash
# Makes the release files in dist/release/: sway-desktop-stats_all.deb and SHA256SUMS (signed later, locally,
# with icenux-app-sign-upload.sh; the signing key never reaches GitHub).
#
# Usage: bash packaging/package.sh VERSION     (needs nfpm in PATH; VERSION must match the file ./VERSION)
set -euo pipefail
umask 022
cd "$(dirname "$0")/.."

VERSION=${1:?usage: packaging/package.sh VERSION}
export VERSION
built=$(head -1 VERSION | tr -d '[:space:]')
[ "$built" = "$VERSION" ] || { echo "Version in VERSION ($built) != $VERSION" >&2; exit 1; }
out=dist/release
rm -rf "$out" && mkdir -p "$out"

nfpm package --config packaging/nfpm.yaml --packager deb --target "$out/sway-desktop-stats_all.deb"
(cd "$out" && sha256sum sway-desktop-stats_all.deb > SHA256SUMS)
ls -l "$out"
