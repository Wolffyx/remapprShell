#!/usr/bin/env bash
# Tests the update pipeline against a copy of the repo, in a throwaway HOME.
#
# Nothing here touches the real checkout: update.sh derives its own REPO_ROOT
# from its location, so running a copy's update.sh updates that copy.
set -uo pipefail

SOURCE_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SOURCE_REPO/tests/lib/harness.sh"
harness_init
mkdir -p "$HOME/.local/bin"

# `update.sh` runs preflight first, and preflight fails outright without a
# Plasma session and the binaries the shell is installed against. A container
# has neither, so the honest answer there is that this suite did not run --
# not that the updater is broken. Same shape as the guards in test-windows.sh.
for tool in plasmashell quickshell; do
    command -v "$tool" >/dev/null 2>&1 \
        || { printf '  SKIP  %s not available; the update pipeline needs a desktop\n' "$tool"; exit 0; }
done

# The installation being updated, and the newer version it updates to.
INSTALLED="$SANDBOX/installed"
NEWER="$SANDBOX/newer"
# The working tree, not `git ls-files`: an uncommitted change is exactly what
# is usually being tested, and copying only tracked files silently omits it.
# Less what is built or rendered in it rather than written: `make plugin`'s
# build directory was most of every copy, and the copy is made three times.
mkdir -p "$INSTALLED"
tar -C "$SOURCE_REPO" --exclude=.git --exclude=./build --exclude='./dev/preview/root.*' -cf - . \
    | tar -C "$INSTALLED" -xf -
cp -a "$INSTALLED" "$NEWER"

echo "0.9.9" > "$NEWER/VERSION"
printf '// added by the newer version\n' >> "$NEWER/shell/core/Obj.qml"

check "starts at the old version" "$(cat "$INSTALLED/VERSION")" "$(cat "$SOURCE_REPO/VERSION")"

echo "== update --from =="
"$INSTALLED/scripts/update.sh" --from "$NEWER" >"$SANDBOX/out" 2>&1
# Taken before anything else runs: `$?` after the `check` below is the check's
# own status, so the diagnostic was never printed on the one occasion it was
# wanted -- an update that failed in CI reported six failed assertions and not
# one line of why.
rc=$?
[ "$rc" -eq 0 ] || { echo "update failed:"; sed 's/^/    /' "$SANDBOX/out"; }
check "the real shell is left running" "$(grep -c 'no session: not restarting' "$SANDBOX/out")" "1"

check "version advanced"            "$(cat "$INSTALLED/VERSION")" "0.9.9"
check "new source content arrived"  "$(grep -c 'added by the newer version' "$INSTALLED/shell/core/Obj.qml")" "1"
check "a restore point was taken"   "$(ls -1 "$XDG_STATE_HOME/$SLUG-snapshots" 2>/dev/null | wc -l)" "1"
check "update state recorded"       "$([ -f "$STATE_DIR/update-state.json" ] && echo yes)" "yes"
check "installed into the sandbox"  "$([ -e "$QS_CONFIG_DIR" ] && echo yes)" "yes"

echo "== rollback =="
"$INSTALLED/scripts/update.sh" --rollback >>"$SANDBOX/out" 2>&1
# The sandbox copy has no git history, so a rollback cannot check anything out.
# What must still hold is that it fails loudly rather than half-applying.
check "rollback without history is refused, not silent" \
      "$(grep -c 'nothing to roll back\|could not check out\|no commit' "$SANDBOX/out")" "1"

echo "== a broken update is refused =="
BROKEN="$SANDBOX/broken"
cp -a "$NEWER" "$BROKEN"
printf 'this is not valid qml {{{\n' > "$BROKEN/shell/core/Obj.qml"
echo "1.0.0" > "$BROKEN/VERSION"

"$INSTALLED/scripts/update.sh" --from "$BROKEN" >"$SANDBOX/broken-out" 2>&1 || true
check "a version that fails its own lint is rejected" \
      "$(grep -c 'does not pass its own QML lint' "$SANDBOX/broken-out")" "1"

harness_done
