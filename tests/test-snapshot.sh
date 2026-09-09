#!/usr/bin/env bash
# Tests snapshot and restore inside a throwaway HOME.
#
# This exists because an earlier version of snapshot_restore deleted a real
# user's KDE configuration. Destructive code must be exercised against a fake
# home, never a real one -- so this test builds one, populates it, and asserts
# on the result.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

# Everything below runs against these, never the caller's real directories.
export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"

pass=0; fail=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }

# --- a plausible KDE home -------------------------------------------------

printf '[General]\noriginal=yes\n' > "$XDG_CONFIG_HOME/kdeglobals"
printf '[Shell]\nShellPackage=something\n' > "$XDG_CONFIG_HOME/plasmashellrc"
printf '[Containments][1]\nplugin=org.kde.panel\n' > "$XDG_CONFIG_HOME/plasma-test.desktop-appletsrc"
mkdir -p "$XDG_CONFIG_HOME/autostart"
printf 'x\n' > "$XDG_CONFIG_HOME/autostart/someapp.desktop"
mkdir -p "$PLASMA_LNF_DIR/preexisting.lookandfeel"
printf 'theirs\n' > "$PLASMA_LNF_DIR/preexisting.lookandfeel/metadata.json"
mkdir -p "$CONFIG_DIR"
printf '{"schemaVersion":1}\n' > "$CONFIG_DIR/state.json"

echo "== snapshot =="
snap=$(snapshot_create preinstall) || { echo "snapshot_create failed" >&2; exit 1; }
check "snapshot directory exists" "$([ -d "$snap" ] && echo yes)" "yes"
check "snapshot store is outside the state dir" \
      "$(case "$(snapshot_root)" in "$STATE_DIR"/*) echo inside ;; *) echo outside ;; esac)" "outside"

echo "== modify, the way the theme layer will =="
printf '[General]\noriginal=no\nplanted=yes\n' > "$XDG_CONFIG_HOME/kdeglobals"
printf '[KSplash]\nTheme=planted\n' > "$XDG_CONFIG_HOME/ksplashrc"          # did not exist before
mkdir -p "$PLASMA_LNF_DIR/ours.lookandfeel"
printf 'ours\n' > "$PLASMA_LNF_DIR/ours.lookandfeel/metadata.json"
mkdir -p "$STATE_DIR"
printf 'junk\n' > "$STATE_DIR/ledger.json"                                   # ours, created since
rm -f "$XDG_CONFIG_HOME/autostart/someapp.desktop"                           # a deletion to undo

echo "== restore =="
snapshot_restore "$snap" || { echo "snapshot_restore failed" >&2; exit 1; }

echo "== assertions =="
check "modified file restored"          "$(grep -c 'original=yes' "$XDG_CONFIG_HOME/kdeglobals")" "1"
check "planted key gone"                "$(grep -c 'planted' "$XDG_CONFIG_HOME/kdeglobals")" "0"
check "deleted file is back"            "$([ -e "$XDG_CONFIG_HOME/autostart/someapp.desktop" ] && echo yes)" "yes"
check "pre-existing look-and-feel kept" "$([ -e "$PLASMA_LNF_DIR/preexisting.lookandfeel/metadata.json" ] && echo yes)" "yes"

# The blast-radius rule: a KDE file created since is left alone, because
# deleting the wrong file is unrecoverable while leaving one is a nuisance.
check "KDE file created since is NOT deleted" "$([ -e "$XDG_CONFIG_HOME/ksplashrc" ] && echo yes)" "yes"
check "our own stray state IS removed"        "$([ -e "$STATE_DIR/ledger.json" ] && echo yes || echo no)" "no"

# The case that destroyed a real look-and-feel directory: a package installed
# after the snapshot lives inside a captured directory, and must survive.
check "package added to a captured dir survives" \
      "$([ -e "$PLASMA_LNF_DIR/ours.lookandfeel/metadata.json" ] && echo yes)" "yes"

# The failure that caused real damage: the archive must survive its own use.
check "snapshot survived being restored"  "$([ -s "$snap/manifest.txt" ] && echo yes)" "yes"
check "snapshot can be restored twice"    "$(snapshot_restore "$snap" >/dev/null 2>&1 && echo yes)" "yes"

echo "== fail-closed =="
broken=$(mktemp -d); mkdir -p "$broken/files"; : > "$broken/manifest.txt"
check "empty manifest is refused" "$(snapshot_restore "$broken" >/dev/null 2>&1 && echo restored || echo refused)" "refused"
check "nothing deleted after refusal" "$([ -e "$XDG_CONFIG_HOME/kdeglobals" ] && echo yes)" "yes"
rm -rf "$broken"

echo
if [ "$fail" -gt 0 ]; then
    printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2
    exit 1
fi
printf 'OK: %d passed\n' "$pass"
