#!/usr/bin/env bash
# Smoke test of sysstats.sh, install.sh and uninstall.sh in a throw-away $HOME.
# pkill, waybar and setsid are replaced by harmless stand-ins, so nothing on the real system
# (including a waybar that is running right now) is touched. Needs jq.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
WB="$HOME/.config/waybar"
SW="$HOME/.config/sway"
mkdir -p "$WB" "$SW" "$TMP/bin"
for stub in pkill waybar; do
  printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/$stub"
  chmod +x "$TMP/bin/$stub"
done
printf '#!/bin/sh\nexec "$@"\n' > "$TMP/bin/setsid"
chmod +x "$TMP/bin/setsid"
export PATH="$TMP/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }
count_exec() { grep -cF "desktop-stats-widget.sh" "$SW/config" || true; }

echo "== sysstats.sh prints valid JSON for waybar"
# an unreachable URL for the public-IP lookup: no network traffic, and it exercises the user-config override
echo 'PUBLIC_IP_URL="http://127.0.0.1:9/"' > "$WB/desktop-stats.conf"
out=$("$ROOT/scripts/sysstats.sh")
echo "$out" | jq -e '.text | length > 0' > /dev/null || fail "sysstats.sh did not print {\"text\": ...}"
rm "$WB/desktop-stats.conf"

echo "== install.sh"
echo "# my sway config" > "$SW/config"
"$ROOT/install.sh" > /dev/null
for f in desktop-stats.jsonc desktop-stats.css desktop-stats.conf.example scripts/sysstats.sh; do
  [ -f "$WB/$f" ] || fail "missing $WB/$f"
done
[ -x "$WB/scripts/sysstats.sh" ] || fail "sysstats.sh is not executable"
[ -x "$SW/scripts/desktop-stats-widget.sh" ] || fail "launch guard missing or not executable"
[ "$(count_exec)" = 1 ] || fail "expected exactly one exec line in the sway config"

echo "== install.sh again: idempotent, backs up the existing files"
"$ROOT/install.sh" > /dev/null
[ "$(count_exec)" = 1 ] || fail "second install duplicated the exec line"
ls "$WB"/desktop-stats.jsonc.bak.* > /dev/null 2>&1 || fail "no backup of desktop-stats.jsonc"

echo "== uninstall.sh"
"$ROOT/uninstall.sh" > /dev/null
for f in desktop-stats.jsonc desktop-stats.css scripts/sysstats.sh; do
  [ ! -e "$WB/$f" ] || fail "$WB/$f was not removed"
done
[ ! -e "$SW/scripts/desktop-stats-widget.sh" ] || fail "launch guard was not removed"
[ "$(count_exec)" = 0 ] || fail "exec line was not removed from the sway config"
grep -qF "# my sway config" "$SW/config" || fail "uninstall.sh damaged the rest of the sway config"

echo "OK"
