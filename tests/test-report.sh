#!/usr/bin/env bash
# Tests the diagnostic report bundle inside a throwaway HOME.
#
# What this is really checking is that a report cannot leak. The redaction
# rules themselves are covered by test-redact.sh; here the question is whether
# the reporter actually applies them -- to the config, to the journal tail and
# to widget health -- and whether the bundle stays readable by its owner alone.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
export "$NO_SESSION_VAR=1"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }
absent() { if grep -qF -- "$3" "$2" 2>/dev/null; then
               printf '  FAIL  %s (found %q in %s)\n' "$1" "$3" "$2" >&2; fail=$((fail+1));
           else printf '  PASS  %s\n' "$1"; pass=$((pass+1)); fi; }

# A configuration with things in it that must not come out the other side.
profile="$CONFIG_DIR/profiles/default/shell.json"
mkdir -p "$(dirname "$profile")"
cat > "$profile" <<PROFILE
{
    "panel": { "position": "top", "thickness": 44 },
    "wallpaper": "$HOME/Pictures/holiday.png",
    "widgets": {
        "weather": { "apiToken": "sk-live-must-not-appear", "city": "Berlin" }
    }
}
PROFILE

mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/widget-health.json" <<HEALTH
{ "quarantined": { "weather": { "lastError": "failed loading $HOME/.local/share/x.qml" } } }
HEALTH

out=$("$REPO_ROOT/scripts/report.sh" create --reason "a test" 2>/dev/null | tail -1)
dir=$out

check "bundle created"        "$([ -d "$dir" ] && echo yes)" "yes"
for f in error.txt environment.txt config.json redaction.txt journal.txt widget-health.json; do
    check "has $f"            "$([ -f "$dir/$f" ] && echo yes)" "yes"
done

check "reason recorded"       "$(sed -n 's/^reason: //p' "$dir/error.txt")" "a test"
check "config still parses"   "$(jq -r '.panel.position' "$dir/config.json")" "top"
check "harmless value kept"   "$(jq -r '.widgets.weather.city' "$dir/config.json")" "Berlin"
check "token masked"          "$(jq -r '.widgets.weather.apiToken' "$dir/config.json")" "<redacted>"
check "home path shortened"   "$(jq -r '.wallpaper' "$dir/config.json")" "~/Pictures/holiday.png"

absent "the token is nowhere in the bundle" <(cat "$dir"/*) "sk-live-must-not-appear"
absent "no absolute home path in the config"  "$dir/config.json" "$HOME"
absent "no absolute home path in health"      "$dir/widget-health.json" "$HOME"

# The report is written by the same code path whether the shell is alive or
# dead, so the case that matters is the one where the profile is broken --
# which is itself a likely reason for writing a report at all.
echo "{ not json" > "$profile"
dir2=$("$REPO_ROOT/scripts/report.sh" create --reason "broken profile" 2>/dev/null | tail -1)
check "still writes a bundle" "$([ -f "$dir2/config.json" ] && echo yes)" "yes"
check "says the profile is broken" "$(grep -c 'does not parse' "$dir2/error.txt")" "1"
check "falls back to defaults" "$(jq -r '.panel.renderer' "$dir2/config.json")" "quickshell"

check "bundle is private"     "$(stat -c '%a' "$dir")" "700"
check "files are private"     "$(stat -c '%a' "$dir/config.json")" "600"

check "listed"                "$("$REPO_ROOT/scripts/report.sh" list 2>/dev/null | grep -c 'a test')" "1"
"$REPO_ROOT/scripts/report.sh" remove "$(basename "$dir")" >/dev/null 2>&1
check "removed"               "$([ -d "$dir" ] && echo yes || echo no)" "no"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
