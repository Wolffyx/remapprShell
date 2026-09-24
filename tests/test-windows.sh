#!/usr/bin/env bash
# Tests the window daemon inside a throwaway HOME.
#
# The daemon is the piece that exists only because a KWin script can call DBus
# but cannot be called. What matters about it is not that it holds a list --
# that is four lines -- but that a bad payload cannot blank a panel, and that
# two copies cannot answer with two different lists.
#
# It owns a real name on the real session bus, so it runs under a name of its
# own here rather than the one an installed shell would be using.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/scripts/lib/render.sh"
DAEMON_PID=""
harness_on_exit '[ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null'

# KWin's own window behaviour: kwinrc keys, written through the ledger. What
# matters is that a bad value never reaches kwinrc, that a write is recorded
# with what was there before, and that revert puts it back exactly -- an
# unset key deleted again rather than left empty.
echo "== KWin's window behaviour =="
BEHAVE=("$REPO_ROOT/scripts/windows.sh" behaviour)
behave() { env "$NO_SESSION_VAR=1" PATH="$FAKES:$PATH" "${BEHAVE[@]}" "$@" 2>&1; }
kwinrc_key() { kread kwinrc Windows "$1"; }

FAKES="$SANDBOX/fakes"
mkdir -p "$FAKES"
for cmd in qdbus6 busctl systemctl kquitapp6; do
    printf '#!/usr/bin/env bash\necho "$0 $*" >> %s/reached-kde.txt\nexit 0\n' "$SANDBOX" > "$FAKES/$cmd"
    chmod +x "$FAKES/$cmd"
done

check "an unknown setting is refused"    "$(behave set nosuch true >/dev/null 2>&1; echo $?)" "1"
check "a bool takes only true or false"  "$(behave set autoRaise sometimes >/dev/null 2>&1; echo $?)" "1"
check "an enum takes only its values"    "$(behave set focus Whatever >/dev/null 2>&1; echo $?)" "1"
check "a number outside the range"       "$(behave set focusDelay 99999 >/dev/null 2>&1; echo $?)" "1"
check "nothing was written by a refusal" "$(kwinrc_key FocusPolicy)" "<unset>"

behave set focus FocusFollowsMouse >/dev/null
check "focus policy written"             "$(kwinrc_key FocusPolicy)" "FocusFollowsMouse"
behave set borderlessMaximized true >/dev/null
check "borderless maximised written"     "$(kwinrc_key BorderlessMaximizedWindows)" "true"
check "status reads them back"           "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .value')" "FocusFollowsMouse"
check "and says what the default was"    "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .default')" "ClickToFocus"
check "the ledger has both"              "$(ledger_count windows-behaviour)" "2"

behave revert >/dev/null
check "revert deletes a key that was unset" "$(kwinrc_key FocusPolicy)" "<unset>"
check "and the other one too"               "$(kwinrc_key BorderlessMaximizedWindows)" "<unset>"
check "the ledger is empty again"           "$(ledger_count windows-behaviour)" "0"
check "nothing reached KDE"                 "$([ -f "$SANDBOX/reached-kde.txt" ] && cat "$SANDBOX/reached-kde.txt" || echo none)" "none"

command -v busctl >/dev/null 2>&1 || { echo "  SKIP  busctl not available"; exit 0; }
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || { echo "  SKIP  no session bus"; exit 0; }
python3 -c "import gi; gi.require_version('Gio','2.0')" 2>/dev/null || { echo "  SKIP  python-gobject not installed"; exit 0; }

# A name of its own: the installed daemon may be running on this bus, and two
# daemons answering one name is the thing the daemon itself refuses to do.
#
# That name is also what stops this copy touching the user's global shortcuts.
# It runs against the *real* session bus -- there is no other -- so a daemon
# that claimed the shell's kglobalaccel component here would unbind the keys on
# the machine running the tests, which is exactly what happened once. Belt and
# braces: the no-session variable as well, set by the harness for every suite
# and honoured by the daemon too.
TEST_NAME="com.remappr.ShellTest$$"
DAEMON="$SANDBOX/windowsd"
render_template "$REPO_ROOT/bin/windowsd.py.in" "$DAEMON"
# BUS_NAME and INTERFACE by name, and nothing else. SHORTCUT_OWNER keeps the
# shell's own name, because BUS_NAME differing from it is the guard: a sed
# over every quoted "$DBUS_NAME" renamed both, and left this copy believing
# it owned the keys, with only the no-session variable standing in the way.
python3 - "$DAEMON" "$TEST_NAME" <<'PY'
import re, sys
path, name = sys.argv[1], sys.argv[2]
src = open(path).read()
src = re.sub(r'^BUS_NAME = .*$', f'BUS_NAME = "{name}"', src, flags=re.M)
src = re.sub(r'^INTERFACE = .*$', f'INTERFACE = "{name}.Windows"', src, flags=re.M)
open(path, 'w').write(src)
PY

# Without a display: this copy has no business sweeping the X11 windows of
# whoever is running the tests, and the icons are checked on their own below.
env -u DISPLAY python3 "$DAEMON" & DAEMON_PID=$!
for _ in $(seq 1 40); do
    busctl --user --json=short call "$TEST_NAME" /Windows "$TEST_NAME.Windows" List >/dev/null 2>&1 && break
    sleep 0.25
done

call() { busctl --user --json=short call "$TEST_NAME" /Windows "$TEST_NAME.Windows" "$@" 2>/dev/null; }
list()  { call List | jq -r '.data[0]'; }

check "starts empty"          "$(list)" "[]"

# The guard that keeps this test off the user's keyboard. Checked here rather
# than only in the unit block below, because this is the copy that would do the
# damage: if it ever registers a component, the live session loses its keys.
check "it claims no shortcuts" \
    "$(busctl --user --json=short call org.kde.kglobalaccel /kglobalaccel \
        org.kde.KGlobalAccel allComponents 2>/dev/null \
        | grep -c "ShellTest" || true)" "0"

WINDOW='[{"uuid":"a","title":"Work","appId":"org.kde.dolphin","minimized":false,"active":true}]'
call Update s "$WINDOW" >/dev/null
check "holds what it is given" "$(list | jq -r '.[0].title')" "Work"
check "one window"             "$(list | jq -r 'length')" "1"

# The rule the whole thing rests on: a payload that cannot be read must leave
# the last good list in place. A blank panel is the failure being designed
# against, and it is worse than a stale one.
call Update s 'not json at all' >/dev/null
check "junk leaves the list alone"  "$(list | jq -r '.[0].title')" "Work"
call Update s '{"not":"a list"}' >/dev/null
check "a non-list is refused"       "$(list | jq -r 'length')" "1"
call Update s '' >/dev/null
check "an empty payload is refused" "$(list | jq -r 'length')" "1"

# But an empty list is a legitimate answer: every window really can be closed.
call Update s '[]' >/dev/null
check "no windows is accepted"      "$(list)" "[]"

# The same, end to end through the daemon, for a process of this test's own:
# what the shell is sent for a window matches what /proc says, and the
# environment's other variables are not in it.
MOUNTED="$SANDBOX/mounted-app"
mkdir -p "$MOUNTED"
printf '[Desktop Entry]\nType=Application\nName=Mounted Example\nIcon=mounted\n' > "$MOUNTED/example.desktop"
env -i PATH="$PATH" APPDIR="$MOUNTED" PRIVATE_THING=do-not-send sleep 300 &
SLEEPER=$!
harness_on_exit 'kill "$SLEEPER" 2>/dev/null'
call Update s "[{\"uuid\":\"p\",\"title\":\"Proc\",\"appId\":\"example.nothing\",\"pid\":$SLEEPER}]" >/dev/null
check "the window carries its command line"   "$(list | jq -r '.[0].cmdline')" "sleep 300"
check "and its process's name"                "$(list | jq -r '.[0].processName')" "sleep"
check "and which of its words are programs"   "$(list | jq -c '.[0].executables')" '["sleep"]'
check "and the desktop file its environment names" "$(list | jq -r '.[0].desktopHint.name')" "Mounted Example"
check "and nothing else of the environment"   "$(list | grep -c do-not-send)" "0"
call Update s '[]' >/dev/null

# The signal is what the shell actually follows.
#
# One monitor watches both cases, and is waited for rather than slept for.
# It is listening once a signal sent after it started has reached it, so it is
# sent probes until one does. That was two monitors and six seconds of sleep,
# the second monitor started while the first was still writing to the same
# file.
monitor_out="$SANDBOX/monitor.json"
timeout 20 busctl --user --json=short monitor --match "type='signal',interface='$TEST_NAME.Windows'" > "$monitor_out" 2>&1 &
monitor_pid=$!
seen() {   # seen <text> <count>: up to five seconds for that many lines with it
    local i
    for i in $(seq 1 100); do
        [ "$(grep -c -- "$1" "$monitor_out")" -ge "$2" ] && return 0
        sleep 0.05
    done
    return 1
}
for _ in $(seq 1 100); do
    busctl --user emit /Windows "$TEST_NAME.Windows" Listening 2>/dev/null
    sleep 0.05
    grep -q '"member":"Listening"' "$monitor_out" && break
done

call Update s "$WINDOW" >/dev/null
seen '"member":"Changed"' 1
check "announces a change"     "$(grep -c '"member":"Changed"' "$monitor_out")" "1"

# KWin repeats itself -- the same list arrives again on events that changed
# nothing -- and a signal per repeat would wake the shell for no reason.
#
# A real change after the repeat marks the end: one sender's signals arrive in
# the order they were sent, so once its signal is in, any the repeat sent is in
# too. Two in all -- the change above and the marker -- means the repeat said
# nothing.
call Update s "$WINDOW" >/dev/null
call Update s '[{"uuid":"b","title":"end-of-test","appId":"x","minimized":false,"active":false}]' >/dev/null
seen 'end-of-test' 1
check "says nothing when nothing changed" "$(( $(grep -c '"member":"Changed"' "$monitor_out") - 2 ))" "0"
kill "$monitor_pid" 2>/dev/null

# Closing a window writes the id into a KWin script's source, so anything
# that is not exactly a uuid must be refused before it gets that far -- and
# with no session, nothing may reach KWin at all.
echo "== closing a window =="
nosession() { env "$NO_SESSION_VAR=1" "$REPO_ROOT/scripts/windows.sh" "$@" 2>&1; }
out=$(nosession close 'a"); workspace.windowList().forEach(w => w.closeWindow()); ("'); status=$?
check "a script in place of an id is refused" "$status:$(printf '%s' "$out" | grep -c 'not a window id')" "1:1"
out=$(nosession close ''); status=$?
check "no id is refused"                      "$status" "1"
out=$(nosession close 1f46c057-675a-4d51-99e5-17aafdfb5b06); status=$?
check "no session, nothing closed"            "$status:$(printf '%s' "$out" | grep -c 'no session')" "1:1"

# The blocks below read the daemon's source rather than a rendered copy, so
# they put in the placeholders that are not names: the tables it shares with
# lib/accel.sh, worked out the way an install renders them.
render_tables; export ACCEL_KEYCODES SHORTCUT_ACTIONS

# Icon extraction. The parsing is what matters here: `_NET_WM_ICON` arrives
# from another application, holds several sizes one after another, and a
# malformed one must yield nothing rather than an exception in the daemon
# everything else depends on.
echo "== icons taken from the windows themselves =="
python3 - "$REPO_ROOT" <<'PYTEST'
import sys, importlib.util, re, os
repo = sys.argv[1]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@ACCEL_KEYCODES@": os.environ["ACCEL_KEYCODES"],
             "@SHORTCUT_ACTIONS@": os.environ["SHORTCUT_ACTIONS"]}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)
largest = mod["WindowIcons"]._largest

def case(name, values, expect):
    got = largest(values)
    ok = (got is None and expect is None) or (got is not None and (got[0], got[1]) == expect)
    print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    return ok

fails = 0
# One 2x2 icon.
fails += not case("reads a single size", [2, 2] + [0] * 4, (2, 2))
# Two sizes: the bigger one wins, because it is the one worth drawing.
fails += not case("prefers the larger size", [2, 2] + [0] * 4 + [4, 4] + [0] * 16, (4, 4))
# Absurd dimensions and truncated data are what a malformed property looks like.
fails += not case("refuses absurd dimensions", [99999, 99999, 1], None)
fails += not case("refuses truncated data", [4, 4, 1, 2, 3], None)
fails += not case("refuses nothing at all", [], None)
fails += not case("refuses a zero size", [0, 0], None)
# A size beyond what a panel would draw is skipped, but a usable one after it
# is still found.
fails += not case("skips a size too large to draw", [512, 1] + [0] * 512 + [8, 1] + [0] * 8, (8, 1))
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+7)); else fail=$((fail+1)); fi

# Where the icons are written. A copy of what a window holds is worth keeping
# only while the window can be, so they go to the session's runtime
# directory, which logout empties -- not the state directory, where they
# outlived every session. The directories are the user's alone.
echo "== window icons live in the session's runtime directory =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os, io, stat, tempfile, contextlib
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@ACCEL_KEYCODES@": os.environ["ACCEL_KEYCODES"],
             "@SHORTCUT_ACTIONS@": os.environ["SHORTCUT_ACTIONS"]}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)
icon_dir = mod["icon_dir"]

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
    fails += 0 if ok else 1

def mode(path):
    return oct(stat.S_IMODE(os.stat(path).st_mode))

run = os.path.join(sandbox, "run")
os.makedirs(run, mode=0o700)
os.environ["XDG_RUNTIME_DIR"] = run
found = icon_dir()
check("under the runtime directory",       found, os.path.join(run, "t", "window-icons"))
check("private all the way down",          [mode(os.path.join(run, "t")), mode(found)], ["0o700", "0o700"])
check("the same one when asked again",     icon_dir(), found)
check("nothing in the state directory",    os.path.exists(os.path.join(os.environ["XDG_STATE_HOME"], "t")), False)

# No runtime directory, or one that cannot be written: a directory of the
# daemon's own in the temporary one, made once rather than once an icon.
tmp = os.path.join(sandbox, "tmp")
os.makedirs(tmp)
tempfile.tempdir = tmp
del os.environ["XDG_RUNTIME_DIR"]
said = io.StringIO()
with contextlib.redirect_stderr(said):
    fallback = icon_dir()
    again = icon_dir()
check("without one, a private directory",  (os.path.dirname(fallback), mode(fallback)), (tmp, "0o700"))
check("made once, not once an icon",       again, fallback)
check("and it says where",                 fallback in said.getvalue(), True)
os.environ["XDG_RUNTIME_DIR"] = os.path.join(sandbox, "not-a-directory")
open(os.environ["XDG_RUNTIME_DIR"], "w").close()
with contextlib.redirect_stderr(io.StringIO()):
    check("an unusable one falls back too", icon_dir(), fallback)
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+8)); else fail=$((fail+1)); fi

# What Plasma reads about the process behind a window, for the shell to match
# it by when the window itself matches no application: the command line and
# the name KProcessList makes of it, and of the environment two variables and
# nothing else. Read from a /proc made up here, so every case is one the test
# decides.
echo "== what Plasma reads about a window's process =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os, json
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@ACCEL_KEYCODES@": os.environ["ACCEL_KEYCODES"],
             "@SHORTCUT_ACTIONS@": os.environ["SHORTCUT_ACTIONS"]}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)
Processes = mod["Processes"]

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
    fails += 0 if ok else 1

root = os.path.join(sandbox, "procfacts")
proc = os.path.join(root, "proc")
def write(path, data, mode=0o644):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb" if isinstance(data, bytes) else "w") as handle:
        handle.write(data)
    os.chmod(path, mode)
    return path
def process(pid, comm="example", cmdline=b"", environ=b""):
    write(os.path.join(proc, str(pid), "stat"), f"{pid} ({comm}) S 1 1 1 0 -1")
    write(os.path.join(proc, str(pid), "cmdline"), cmdline)
    write(os.path.join(proc, str(pid), "environ"), environ)

# The command line, as KProcessList gives it.
process(101, cmdline=b"/opt/example/bin/example-viewer\0--open\0some file.txt\0")
check("NULs are spaces",                 Processes.command(101, proc),
      ("/opt/example/bin/example-viewer --open some file.txt", "example-viewer"))
process(102, cmdline=b"C:\\Programs\\Example App\\app.exe\0" + b"\0" * 40)
check("the padding a program leaves is trimmed, and a name with no slash is whole",
      Processes.command(102, proc), ("C:\\Programs\\Example App\\app.exe", "C:\\Programs\\Example App\\app.exe"))
process(103, comm="kernel-thing")
check("no arguments: the kernel's name for it", Processes.command(103, proc), ("kernel-thing", "kernel-thing"))
check("a process that cannot be read gives nothing", (Processes.command(999, proc), Processes.read(999, proc)), (None, {}))
process(104, cmdline=b"x" * 5000)
check("a command line is cut where no Exec line reaches", len(Processes.read(104, proc, path="")["cmdline"]), 4096)

# The words of it that are programs on PATH -- QStandardPaths' rules, not
# shutil.which's: a relative path is looked for on PATH too.
bindir = os.path.join(root, "bin")
write(os.path.join(bindir, "example-tool"), "#!/bin/sh\n", 0o755)
write(os.path.join(bindir, "not-a-program"), "", 0o644)
write(os.path.join(bindir, "sub", "tool"), "#!/bin/sh\n", 0o755)
absolute = write(os.path.join(root, "elsewhere", "example-run"), "#!/bin/sh\n", 0o755)
line = f"example-tool not-a-program sub/tool {absolute} --flag example-tool"
check("the programs among the words, once each", Processes.executables(line, bindir),
      ["example-tool", "sub/tool", absolute])
check("only the first sixteen words are looked at",
      Processes.executables(" ".join(["w"] * 16 + ["example-tool"]), bindir), [])

# The environment: two variables, the first one there deciding, and nothing
# else of it kept.
data = os.path.join(root, "data")
os.environ["XDG_DATA_HOME"] = data
os.environ["LANG"] = "de_DE.UTF-8"
hinted = write(os.path.join(data, "applications", "sub", "example-hinted.desktop"),
               "[Desktop Entry]\nType=Application\nName=Hinted\nName[de]=Angedeutet\nIcon=example-hinted\n"
               "[Desktop Action New]\nName=New Window\n")
process(105, environ=b"HOME=/somewhere\0PRIVATE_THING=secret\0"
                     b"BAMF_DESKTOP_FILE_HINT=" + hinted.encode() + b"\0APPDIR=/nowhere\0")
hint = Processes.desktop_hint(105, proc)
check("a desktop file hint, with its id among the installed ones",
      (hint["variable"], hint["path"], hint["id"]), ("BAMF_DESKTOP_FILE_HINT", hinted, "sub-example-hinted"))
check("its name in the session's language, not an action's", hint["name"], "Angedeutet")
check("nothing else of the environment", "secret" in json.dumps(Processes.read(105, proc)), False)

appdir = os.path.join(root, "mounted")
write(os.path.join(appdir, "Zeta.desktop"), "[Desktop Entry]\nName=Zeta\n")
write(os.path.join(appdir, "alpha.desktop"), "[Desktop Entry]\nName=Alpha\nIcon=alpha-icon.svg\n")
write(os.path.join(appdir, "alpha-icon.svg"), "<svg/>")
write(os.path.join(appdir, "alpha-icon.png"), b"png")
process(106, environ=b"APPDIR=" + appdir.encode() + b"\0")
hint = Processes.desktop_hint(106, proc)
check("a mounted application: its first desktop file by name, whatever the case",
      (hint["variable"], hint["name"], hint["id"]), ("APPDIR", "Alpha", ""))
check("and the icon beside it, a PNG first", hint["iconFile"], os.path.join(appdir, "alpha-icon.png"))
empty = os.path.join(root, "empty")
os.makedirs(empty)
process(107, environ=b"APPDIR=" + empty.encode() + b"\0BAMF_DESKTOP_FILE_HINT=" + hinted.encode() + b"\0")
check("the first variable decides even when it names nothing", Processes.desktop_hint(107, proc), None)
process(108, environ=b"APPDIR=" + appdir.encode() + b"\0")
os.chmod(os.path.join(proc, "108", "environ"), 0)
check("an environment that cannot be read gives nothing", Processes.desktop_hint(108, proc), None)

# An app id that is a desktop file's path, as it is or without the suffix.
named = write(os.path.join(root, "files", "example-named.desktop"), "[Desktop Entry]\nName=Named\nIcon=/an/icon.png\n")
app_id_file = mod["app_id_file"]
check("an app id that is a desktop file's path",
      (app_id_file({"desktopFile": named})["name"], app_id_file({"desktopFile": named})["iconFile"]), ("Named", ""))
check("or is one without the suffix", app_id_file({"desktopFile": "", "appId": named[:-8]})["path"], named)
check("but not a name, nor a path to nothing",
      (app_id_file({"appId": "example-named"}), app_id_file({"appId": "/no/such/thing"})), (None, None))

# Kept per process while it has a window, and not after.
class Counting(Processes):
    reads = 0
    @staticmethod
    def read(pid, proc="/proc", path=None):
        Counting.reads += 1
        return {"cmdline": str(pid)}
kept = Counting()
for pid in (5, 5, 6, 5):
    kept.facts_for(pid)
check("read once for each process", Counting.reads, 2)
kept.forget_all_but({6})
kept.facts_for(5)
check("and again once it had gone", Counting.reads, 3)
check("no process, nothing read", (kept.facts_for(0), kept.facts_for(None), Counting.reads), ({}, {}, 3))
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+20)); else fail=$((fail+1)); fi

# A lookup that found nothing is a fact about the moment, not about the
# window: `_NET_WM_ICON` is set a little after the window is mapped, so a
# window asked the instant it appears often has no icon yet. Keeping that
# answer for the life of the daemon is what "some icons are missing until I
# restart the shell" was -- the restart forgot, and that was the whole fix.
# A hit is kept only until KWin says the icon changed: a program that set its
# own icon over its toolkit's first one was otherwise drawn with the first.
echo "== a window's icon is looked at again when it may have changed =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@ACCEL_KEYCODES@": os.environ["ACCEL_KEYCODES"],
             "@SHORTCUT_ACTIONS@": os.environ["SHORTCUT_ACTIONS"]}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)

class Probe(mod["WindowIcons"]):
    """The real path_for, with the display replaced by a script of answers."""
    MISS_RETRY_SECONDS = 0.0        # the waiting is not what is under test

    def __init__(self, script):
        self._x11, self._icons, self._misses, self._written = {}, {}, {}, set()
        self._clients, self._available = None, True
        self.script, self.looks = list(script), 0

    def _x11_window_for(self, uuid, window):
        return "0x1"

    def _extract(self, window):
        self.looks += 1
        return self.script.pop(0) if self.script else None

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
    fails += 0 if ok else 1

def icon(name):
    path = os.path.join(sandbox, name)
    open(path, "w").close()
    return path

def window(uuid="w", serial=0):
    return {"uuid": uuid, "pid": 1, "iconSerial": serial}

# Late, as a toolkit often is: nothing twice, then an icon.
late = icon("late.png")
p = Probe([None, None, late])
check("nothing on the first look",  p.path_for(window()), None)
check("nothing on the second",      p.path_for(window()), None)
check("and the icon on the third",  p.path_for(window()), late)
check("three looks, not one",       p.looks, 3)
check("then it stops looking",      (p.path_for(window()), p.looks), (late, 3))

# The program set its own icon over the first: KWin says so, and it is read
# again however good the copy already kept looked.
first, own = icon("first.png"), icon("own.png")
p = Probe([first, own])
p.path_for(window(serial=0))
check("an icon KWin says changed is read again", (p.path_for(window(serial=1)), p.looks), (own, 2))
check("and kept until it changes again",         (p.path_for(window(serial=1)), p.looks), (own, 2))

# A window that really has no icon must not cost a display sweep for ever --
# until KWin says it has one after all.
p = Probe([])
for _ in range(20):
    p.path_for(window("never"))
check("a real miss gives up",           p.looks, Probe.MISS_ATTEMPTS)
p.path_for(window("never", serial=1))
check("until KWin announces a change",  p.looks, Probe.MISS_ATTEMPTS + 1)

# The path is cached, not the picture, and a path can stop being true.
gone = icon("gone.png")
p = Probe([gone])
p.path_for(window("gone"))
os.unlink(gone)
check("a path that went away is read again", (p.path_for(window("gone")), p.looks), (None, 2))

# Per window, not per application: the second window of a program is asked
# for its own icon rather than handed the first one's.
one, two = icon("one.png"), icon("two.png")
p = Probe([one, two])
check("each window has its own",   [p.path_for(window("a")), p.path_for(window("b"))], [one, two])
check("a window with no process is not looked for",
      (p.path_for({"uuid": "x"}), p.path_for({"uuid": "y", "pid": 0}), p.looks), (None, None, 2))

# Kept while the window is there, and not after: a window that went takes its
# file with it -- but only a file this copy of the daemon wrote.
mine, foreign = icon("mine.png"), icon("foreign.png")
p = Probe([])
p._written.add(mine)
p._icons.update({"went": (0, mine), "stays": (0, one), "stranger": (0, foreign)})
p._x11.update({"went": "0x5", "stays": "0x6"})
p.forget_all_but({"stays"})
check("a window that went takes its icon with it",   os.path.exists(mine), False)
check("and what was found out about it",             ("went" in p._x11, "went" in p._icons), (False, False))
check("a window still there keeps its own",          (p._icons.get("stays"), p._x11.get("stays")), ((0, one), "0x6"))
check("a file this copy did not write is left alone", os.path.exists(foreign), True)
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+16)); else fail=$((fail+1)); fi

# Which X11 window a window is. KWin names no X11 window to a script, so the
# daemon finds it among the display's managed windows -- and "the first window
# of this process" was the wrong answer for a process with several: a helper
# window's stock icon stood for the application's own. The class must agree,
# and the title decides between windows that share it.
echo "== a window's icon comes from that window =="
python3 - "$REPO_ROOT" <<'PYTEST'
import sys, os
repo = sys.argv[1]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@ACCEL_KEYCODES@": os.environ["ACCEL_KEYCODES"],
             "@SHORTCUT_ACTIONS@": os.environ["SHORTCUT_ACTIONS"]}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)
pick, parse = mod["WindowIcons"].pick_client, mod["WindowIcons"].client

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
    fails += 0 if ok else 1

# One process with a helper window listed first and two windows of its own,
# and another process.
clients = [
    {"id": "0xa1", "pid": 7, "instance": "helper",  "class": "Example.Viewer", "name": "Default"},
    {"id": "0xa2", "pid": 7, "instance": "viewer",  "class": "Example.Viewer", "name": "Main"},
    {"id": "0xa3", "pid": 7, "instance": "viewer",  "class": "Example.Viewer", "name": "Second"},
    {"id": "0xa4", "pid": 7, "instance": "tool",    "class": "Example.Tool",   "name": "Tool"},
    {"id": "0xb1", "pid": 8, "instance": "other",   "class": "Other",          "name": "Other"},
]
def window(**over):
    w = {"pid": 7, "appId": "example.viewer", "resourceName": "viewer", "title": "Somewhere"}
    w.update(over)
    return w

check("not the process's first window",           pick(window(), clients, set()), "0xa2")
check("the one with this title",                  pick(window(title="Second"), clients, set()), "0xa3")
check("a title KWin numbered finds its window",   pick(window(title="Second <2>"), clients, set()), "0xa3")
check("not one another window already is",        pick(window(title="Second"), clients, {"0xa3"}), "0xa2")
check("the class decides, not the process",       pick(window(appId="example.tool", resourceName="tool"), clients, set()), "0xa4")
check("no window of that class, no icon",         pick(window(appId="example.missing"), clients, set()), None)
check("another process's window is not this one", pick(window(pid=9, appId="other", resourceName="other"), clients, set()), None)
check("without an instance name the class will do",
      pick({"pid": 8, "appId": "other", "title": ""}, clients, set()), "0xb1")

# What xprop says about a window, read back.
props = ('_NET_WM_PID(CARDINAL) = 4242\n'
         'WM_CLASS(STRING) = "inst", "Klass"\n'
         '_NET_WM_NAME(UTF8_STRING) = "A \\"quoted\\" title"\n')
check("xprop's answer read",   parse("0x1", props),
      {"id": "0x1", "pid": 4242, "instance": "inst", "class": "Klass", "name": 'A "quoted" title'})
check("a window with none of it", parse("0x2", "_NET_WM_PID:  not found.\n"),
      {"id": "0x2", "pid": 0, "instance": "", "class": "", "name": ""})
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+10)); else fail=$((fail+1)); fi

# The shortcuts the daemon owns. Two things can be checked without a session:
# that a key string becomes the integer kglobalaccel wants -- the same numbers
# scripts/lib/accel.sh is checked against, from the same measurements off a
# running server -- and that the component's group is read out of the file the
# way kglobalaccel writes it.
echo "== the shortcuts the daemon owns =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@BIN_DIR@": "/nowhere", "@CTL_BIN@": "t-ctl", "@ALIAS@": "t",
             "@ACCEL_KEYCODES@": os.environ["ACCEL_KEYCODES"],
             "@SHORTCUT_ACTIONS@": os.environ["SHORTCUT_ACTIONS"]}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)
keycode, shortcuts = mod["keycode"], mod["GlobalShortcuts"]

fails = 0
def case(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))

for name, spec, want in [
    ("Print", "Print", 16777225),
    ("Meta+Shift+Print", "Meta+Shift+Print", 318767113),
    ("a letter is its ASCII", "Q", 81),
    ("lower case too", "q", 81),
    ("Meta+Space", "Meta+Space", 268435488),
    ("a function key", "F5", 16777268),
    ("Alt+Tab", "Alt+Tab", 150994945),
    ("every modifier at once", "Meta+Alt+Ctrl+Shift+Delete", 520093703),
    ("Meta alone is a key", "Meta", 16777250),
    ("a modifier nobody knows", "Hyper+Q", None),
    ("a key nobody knows", "Meta+Banana", None),
    ("nothing at all", "", None),
    ("Meta+/, as the file spells it", "Meta+/", 268435503),
    ("Meta+Slash, spelled out", "Meta+Slash", 268435503),
    ("Meta+Shift+S", "Meta+Shift+S", 301989971),
]:
    case(name, keycode(spec), want)

# The file as kglobalaccel keeps it: a component's group, three fields, a tab
# between two keys written as a literal backslash-t.
config = os.path.join(sandbox, "kglobalshortcutsrc")
os.environ["XDG_CONFIG_HOME"] = sandbox
open(config, "w").write(
    "[somebodyelse]\n"
    "launcher=Meta+X,none,Not ours\n"
    "\n"
    "[t]\n"
    "launcher=Meta,none,Application menu\n"
    "search=none,none,Search\n"
    "switcher=Alt+Tab\\tMeta+F1,none,Window switcher\n"
    "nosuchaction=Meta+Z,none,Unknown\n"
)
found = shortcuts.bindings()
case("reads our group only", found.get("launcher"), ["Meta"])
case("an unbound action is empty", found.get("search"), [])
case("two keys on one action", found.get("switcher"), ["Alt+Tab", "Meta+F1"])
case("an action we do not know is ignored", "nosuchaction" in found, False)

# Ownership: only the daemon holding the shell's own bus name claims the
# shell's keys. A second copy that did would take them off the first, on the
# live session, which is what the test suite itself once did.
wanted = mod["shortcuts_wanted"]
os.environ.pop(mod["NO_SESSION_VAR"], None)
mod["BUS_NAME"] = mod["SHORTCUT_OWNER"]
case("the daemon that owns the name claims them", wanted(), True)
mod["BUS_NAME"] = mod["SHORTCUT_OWNER"] + "Test1234"
case("a copy under another name claims nothing", wanted(), False)
mod["BUS_NAME"] = mod["SHORTCUT_OWNER"]
os.environ[mod["NO_SESSION_VAR"]] = "1"
case("and neither does one with no session", wanted(), False)

sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+19)); else fail=$((fail+1)); fi

# Both run on the thread that answers D-Bus, so both are about time. Finding
# the display's windows is an xprop per window on it, and it was done again
# for every window in an update that had no icon yet; and the icon's pixels
# were reordered one at a time in Python.
echo "== the daemon's icon work, once an update and not pixel by pixel =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@ACCEL_KEYCODES@": os.environ["ACCEL_KEYCODES"],
             "@SHORTCUT_ACTIONS@": os.environ["SHORTCUT_ACTIONS"]}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
    fails += 0 if ok else 1

class Counting(mod["WindowIcons"]):
    def __init__(self):
        self._x11, self._icons, self._misses, self._written = {}, {}, {}, set()
        self._clients, self._available = None, True
        self.sweeps, self.asked = 0, []
    def _x11_clients(self):
        self.sweeps += 1
        return [{"id": "0x1", "pid": 1, "instance": "", "class": "a", "name": ""},
                {"id": "0x2", "pid": 2, "instance": "", "class": "b", "name": ""}]
    def _extract(self, window):
        self.asked.append(window)
        return None

icons = Counting()
icons.new_update()
for uuid, app, pid in (("u1", "a", 1), ("u2", "b", 2), ("u3", "c", 3)):
    icons.path_for({"uuid": uuid, "appId": app, "pid": pid})
check("one sweep for a whole update", icons.sweeps, 1)
check("and every window found in it", icons.asked, ["0x1", "0x2"])
icons.new_update()
icons.path_for({"uuid": "u4", "appId": "c", "pid": 3})
check("the next update sweeps again", icons.sweeps, 2)
icons.new_update()
icons.path_for({"uuid": "u1", "appId": "a", "pid": 1, "iconSerial": 1})
check("a window found once is not looked for again", (icons.sweeps, icons.asked[-1]), (2, "0x1"))

try:
    from PIL import Image
except ImportError:
    print("  SKIP  Pillow is not installed; the pixels were not checked")
    sys.exit(1 if fails else 0)

# Two pixels, as xprop prints the property: opaque blue, and black at 0x81.
class Run:
    stdout = "_NET_WM_ICON(CARDINAL) = 2, 1, 4278190335, 2164260864"
class FakeSubprocess:
    @staticmethod
    def run(*_args, **_kwargs):
        return Run()
mod["subprocess"] = FakeSubprocess
run = os.path.join(sandbox, "run-pixels")
os.makedirs(run, mode=0o700)
os.environ["XDG_RUNTIME_DIR"] = run
extract = mod["WindowIcons"]._extract
path = extract(icons, "0x1")
image = Image.open(path)
check("written to the runtime directory", os.path.dirname(path), os.path.join(run, "t", "window-icons"))
check("named for the window",     os.path.basename(path).startswith("0x1-"), True)
check("the icon is its size",     image.size, (2, 1))
check("ARGB read as RGBA",        [image.getpixel((0, 0)), image.getpixel((1, 0))],
                                  [(0, 0, 255, 255), (0, 0, 0, 0x81)])
# The shell keeps a picture for as long as its URL is the same: a new icon on
# the same window must be a new file, and the same one read again need not be.
check("the same icon is the same file", extract(icons, "0x1"), path)
Run.stdout = "_NET_WM_ICON(CARDINAL) = 1, 1, 4278190335"
check("a new icon is a new file",       extract(icons, "0x1") != path, True)
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+10)); else fail=$((fail+1)); fi

harness_done
