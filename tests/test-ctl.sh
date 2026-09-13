#!/usr/bin/env bash
# The generated control script: which shell its IPC commands talk to.
#
# Every IPC command used to name the installed config path, so with the shell
# run from a checkout -- `make run`, the way it is run while it is being worked
# on -- `settings`, `sidebar`, `keys`, `clipboard`, `launcher`, `wizard` and
# `reload` all answered "No running instances" with that very shell on screen.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

CTL="$SANDBOX/ctl.sh"
render_template "$REPO_ROOT/bin/ctl.sh.in" "$CTL" || { echo "render failed" >&2; exit 1; }

# The suite says what is running, and what `quickshell ipc` did with it: the
# stub records the --path it was handed instead of talking to anything.
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
[ -n "${FAKE_PROC:-}" ] && printf '%s\n' "$FAKE_PROC"
exit 0
STUB
cat > "$SANDBOX/bin/quickshell" <<'STUB'
#!/usr/bin/env bash
# quickshell ipc --path <path> call ...
while [ $# -gt 0 ]; do
    [ "$1" = "--path" ] && { printf '%s\n' "$2"; exit 0; }
    shift
done
exit 0
STUB
chmod +x "$SANDBOX/bin/pgrep" "$SANDBOX/bin/quickshell"
export PATH="$SANDBOX/bin:$PATH"

installed="$QS_CONFIG_DIR/shell.qml"
checkout="$REPO_ROOT/shell/shell.qml"

echo "== which shell an IPC command talks to =="

export FAKE_PROC="7 /usr/bin/quickshell -n -p $installed"
check "the installed copy"      "$(bash "$CTL" settings)"  "$installed"

export FAKE_PROC="7 /usr/bin/quickshell -n -p $checkout"
check "a run from a checkout"   "$(bash "$CTL" settings)"  "$checkout"
check "and for the sidebar"     "$(bash "$CTL" sidebar)"   "$checkout"
check "and the key sheet"       "$(bash "$CTL" keys)"      "$checkout"
check "and reload"              "$(bash "$CTL" reload)"    "$checkout"
check "and the session screen"  "$(bash "$CTL" session)"   "$checkout"
check "and a page by name"      "$(bash "$CTL" settings appearance)" "$checkout"

# Somebody else's shell is not ours, whatever it is drawing.
export FAKE_PROC="7 /usr/bin/quickshell -n -p /home/other/.config/quickshell/caelestia/shell.qml"
check "someone else's shell"    "$(bash "$CTL" settings)"  "$installed"

# Nothing running is the installed path: the error the user should see is
# quickshell's own "no running instances", naming where it looked.
export FAKE_PROC=""
check "nothing running"         "$(bash "$CTL" settings)"  "$installed"

# A checkout somewhere else entirely -- a git worktree beside the repository,
# which is how this project's own redesign was built. The first version of the
# fix knew two paths, the installed one and this tree, so a shell run from a
# second worktree still answered "No running instances" after it.
OTHER="$SANDBOX/elsewhere"
mkdir -p "$OTHER/shell"
printf '{ "slug": "%s" }\n' "$SLUG" > "$OTHER/branding.json"
export FAKE_PROC="7 /usr/bin/quickshell -n -p $OTHER/shell/shell.qml"
check "another checkout"        "$(bash "$CTL" settings)"  "$OTHER/shell/shell.qml"

# Someone else's Quickshell config is not a checkout of ours, whatever its
# layout: the branding has to name this project.
NOTOURS="$SANDBOX/notours"
mkdir -p "$NOTOURS/shell"
printf '{ "slug": "someone-elses-shell" }\n' > "$NOTOURS/branding.json"
export FAKE_PROC="7 /usr/bin/quickshell -n -p $NOTOURS/shell/shell.qml"
check "another project's tree"  "$(bash "$CTL" settings)"  "$installed"

# The same shape with no branding at all is not ours either.
BARE="$SANDBOX/bare"
mkdir -p "$BARE/shell"
export FAKE_PROC="7 /usr/bin/quickshell -n -p $BARE/shell/shell.qml"
check "no branding, not ours"   "$(bash "$CTL" settings)"  "$installed"

# Both up at once: the installed copy is the one a person who built nothing
# is looking at.
export FAKE_PROC="7 /usr/bin/quickshell -n -p $checkout
8 /usr/bin/quickshell -n -p $installed"
check "both, installed wins"    "$(bash "$CTL" settings)"  "$installed"

# This tree is preferred over a stranger's checkout of the same project.
export FAKE_PROC="7 /usr/bin/quickshell -n -p $OTHER/shell/shell.qml
8 /usr/bin/quickshell -n -p $checkout"
check "this tree wins"          "$(bash "$CTL" settings)"  "$checkout"

# The session screen's kind reaches the shell, and a kind nobody defined is
# refused here rather than at the other end: the IPC takes any string.
echo "== the session screen's kind =="
export FAKE_PROC="7 /usr/bin/quickshell -n -p $installed"
check "a kind is passed through"  "$(bash "$CTL" session promptShutDown)" "$installed"
out=$(bash "$CTL" session nonsense 2>&1); rc=$?
check "an unknown kind refused"   "$rc" "1"
check "and says which are valid"  "$(printf '%s' "$out" | grep -c 'promptShutDown')" "1"

echo "== no command left naming the installed path outright =="
check "none hardcoded" "$(grep -c 'ipc --path "@QS_CONFIG_DIR@' "$REPO_ROOT/bin/ctl.sh.in")" "0"

if [ "$fail" -gt 0 ]; then echo "FAILED: $pass passed, $fail failed" >&2; exit 1; fi
echo "OK: $pass passed"
