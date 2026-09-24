#!/usr/bin/env bash
# Tests the crash-dump commands inside a throwaway HOME.
#
# The question here is whether a crash quickshell caught -- and systemd did
# not -- can be found, read, and turned into a report without leaking the
# things a dump carries: the environment, absolute paths, a username. And
# whether a dump belonging to somebody else's shell is left alone, since the
# dump directory is shared by every quickshell on the machine.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init --cache

CRASHES="$XDG_CACHE_HOME/quickshell/crashes"

# A dump, shaped like the ones quickshell writes.
make_dump() {
    local id=$1 config=$2 when=$3
    mkdir -p "$CRASHES/$id"
    cat > "$CRASHES/$id/report.txt" <<DUMP
===== Version Information =====
Quickshell: 0.3.1 (revision , distributed by Arch Linux)
Qt: 6.11.2 (built against 6.11.2)

===== Build Information =====
Build Type: RelWithDebInfo
Compile Flags: -march=x86-64-v3 -O3 -pipe

===== System Information =====
GPU /dev/dri/renderD128

===== Environment (trimmed) =====
QML2_IMPORT_PATH=$HOME/.config/quickshell/somewhere

===== Instance Information =====
Signal: Segmentation fault (11)
Crashed process ID: 4242
Run ID: $id
Config Path: $config

===== Stacktrace =====
#0  0x00007f0000000000 at /usr/bin/../lib/libc.so.6
#1  0x00007f0000000001 in QV4::Function::call at /usr/bin/../lib/libQt6Qml.so.6

===== Log Tail =====
something happened in $HOME/Documents
DUMP
    touch -d "$when" "$CRASHES/$id"
}

make_dump old-ours   "$QS_CONFIG_DIR/shell.qml"                  "2026-01-01 10:00:00"
make_dump theirs     "$HOME/.config/quickshell/somebody/shell.qml" "2026-01-01 11:00:00"
make_dump new-ours   "$QS_CONFIG_DIR/shell.qml"                  "2026-01-01 12:00:00"

CRASH="$REPO_ROOT/scripts/crash.sh"

# --- listing: ours, oldest first, and nobody else's --------------------------
ids=$("$CRASH" list --ids 2>/dev/null | tr '\n' ' ')
check "lists our dumps, oldest first" "$ids" "old-ours new-ours "
check "somebody else's is not ours"   "$(printf '%s' "$ids" | grep -c theirs)" "0"
check "--all sees every dump"         "$("$CRASH" list --ids --all 2>/dev/null | wc -l)" "3"
check "table form lists two"          "$("$CRASH" list 2>/dev/null | grep -c 'Segmentation fault')" "2"
check "and says what to do"           "$("$CRASH" list 2>&1 | grep -c 'ask --crash')" "1"

# --- show: newest by default, redacted ---------------------------------------
"$CRASH" show > "$SANDBOX/show.txt" 2>/dev/null
check "show exits 0"                  "$?" "0"
present "newest by default"           "$SANDBOX/show.txt" "Run ID: new-ours"
present "the stack is in it"          "$SANDBOX/show.txt" "QV4::Function::call"
present "so is the signal"            "$SANDBOX/show.txt" "Segmentation fault (11)"
absent  "no absolute home path"       "$SANDBOX/show.txt" "$HOME"
# The build and system sections are long, identical on every dump, and already
# covered by the report's own environment part.
absent  "build section dropped"       "$SANDBOX/show.txt" "Compile Flags"

"$CRASH" show old-ours > "$SANDBOX/old.txt" 2>/dev/null
present "a named dump can be shown"   "$SANDBOX/old.txt" "Run ID: old-ours"

"$CRASH" show theirs >/dev/null 2>&1
check "refuses somebody else's dump"  "$?" "1"

# --- a report about a crash ---------------------------------------------------
dir=$("$REPO_ROOT/scripts/report.sh" create --reason "crash new-ours" --crash new-ours 2>/dev/null | tail -1)
check "the bundle has a crash part"   "$([ -f "$dir/crash.txt" ] && echo yes)" "yes"
present "with the stack in it"        "$dir/crash.txt" "QV4::Function::call"
absent  "and no home path"            "$dir/crash.txt" "$HOME"
present "error.txt names the dump"    "$dir/error.txt" "crash:  new-ours"
present "report show prints it"       <("$REPO_ROOT/scripts/report.sh" show "$(basename "$dir")" 2>/dev/null) "===== crash.txt ====="
check "crash files are private"       "$(stat -c '%a' "$dir/crash.txt")" "600"

# A report about a crash that is not there is still a report, and says so.
dir2=$("$REPO_ROOT/scripts/report.sh" create --reason "gone" --crash nope 2>/dev/null | tail -1)
check "a missing dump is not fatal"   "$([ -d "$dir2" ] && echo yes)" "yes"
present "and is said out loud"        "$dir2/error.txt" "no crash dump found"

# --- ask --crash --------------------------------------------------------------
printf '#!/usr/bin/env bash\ncat > %s/clipboard.txt\n' "$SANDBOX" > "$FAKEBIN/wl-copy"
chmod +x "$FAKEBIN/wl-copy"
path_only bash sh jq cat wc cut grep sed awk ls sort tail head date mktemp stat chmod mkdir rm mv cp \
          basename dirname tr printf find touch id uname env seq sleep setsid diff cmp \
          journalctl systemctl coredumpctl kreadconfig6 quickshell

"$REPO_ROOT/scripts/ask.sh" --crash --show > "$SANDBOX/ask.txt" 2>/dev/null
check "ask --crash exits 0"           "$?" "0"
present "it asks about the crash"     "$SANDBOX/ask.txt" "This shell crashed"
present "and carries the stack"       "$SANDBOX/ask.txt" "QV4::Function::call"
check "the bundle is not empty"       "$([ -s "$SANDBOX/ask.txt" ] && echo yes)" "yes"
absent  "still no home path"          "$SANDBOX/ask.txt" "$HOME"

before=$(ls -1 "$STATE_DIR/diagnostics" | wc -l)
"$REPO_ROOT/scripts/ask.sh" --crash --show >/dev/null 2>&1
"$REPO_ROOT/scripts/ask.sh" --crash --show >/dev/null 2>&1
check "one bundle per dump, not per ask" "$(ls -1 "$STATE_DIR/diagnostics" | wc -l)" "$before"

"$REPO_ROOT/scripts/ask.sh" --crash old-ours --show > "$SANDBOX/askold.txt" 2>/dev/null
present "a named dump can be asked about" "$SANDBOX/askold.txt" "Run ID: old-ours"

"$REPO_ROOT/scripts/ask.sh" --crash theirs --show >/dev/null 2>&1
check "refuses somebody else's dump"  "$?" "1"

# --- since: what the shell asks on startup ------------------------------------
#
# The comparison lives here rather than in QML precisely so it can be tested.

check "since 0 names the newest"      "$("$CRASH" since 0 | cut -d' ' -f2)" "new-ours"
check "since now names nothing"       "$("$CRASH" since "$(date +%s)")" ""
newest_epoch=$("$CRASH" since 0 | cut -d' ' -f1)
check "since its own moment is quiet" "$("$CRASH" since "$newest_epoch")" ""
check "a moment before it is not"     "$("$CRASH" since "$((newest_epoch - 1))" | cut -d' ' -f2)" "new-ours"

# The case that got this wrong the first time: the dump that was recorded is
# deleted, and the newest remaining one is OLDER than the moment recorded. By
# identity that reads as a new crash; by time it is what it is -- old news.
rm -rf "$CRASHES/new-ours"
check "an older dump is not new news" "$("$CRASH" since "$newest_epoch")" ""
make_dump new-ours "$QS_CONFIG_DIR/shell.qml" "2026-01-01 12:00:00"

# A crash that happens after the recorded moment is reported, however old the
# recorded id.
make_dump newer-ours "$QS_CONFIG_DIR/shell.qml" "2026-01-02 09:00:00"
check "a genuinely newer dump shows"  "$("$CRASH" since "$newest_epoch" | cut -d' ' -f2)" "newer-ours"
"$CRASH" remove newer-ours >/dev/null 2>&1

# Somebody else's crash is never what this shell came back from.
make_dump theirs-new "$HOME/.config/quickshell/somebody/shell.qml" "2026-01-03 09:00:00"
check "their crash is not ours"       "$("$CRASH" since "$newest_epoch")" ""
rm -rf "$CRASHES/theirs-new"

# --- check: the whole decision the shell makes at startup ---------------------

seen="$STATE_DIR/last-crash"

# A machine that has never run this. Every dump already there predates it, so
# none of them is news -- but the record must still be written, or the next
# start would seed all over again.
rm -f "$seen"
check "a first start reports nothing"  "$("$CRASH" check)" ""
check "and writes the record"          "$([ -f "$seen" ] && echo yes)" "yes"
check "naming the newest it saw"       "$(cut -d' ' -f2 "$seen")" "new-ours"

# An ordinary restart, with nothing new.
check "a restart reports nothing"      "$("$CRASH" check)" ""

# A crash. Reported once, and not again on the next start.
make_dump crash-one "$QS_CONFIG_DIR/shell.qml" "2026-02-01 09:00:00"
check "a new crash is reported"        "$("$CRASH" check | cut -d' ' -f2)" "crash-one"
check "and not a second time"          "$("$CRASH" check)" ""

# The case the first version got wrong: a fresh install with NO dumps at all,
# where the very first crash arrives with no record yet written. Seeding it
# away as history would lose exactly the crash that matters most.
rm -f "$seen"
"$CRASH" remove --all >/dev/null 2>&1
check "a first start with no dumps"    "$("$CRASH" check)" ""
check "still writes a record"          "$([ -f "$seen" ] && echo yes)" "yes"
make_dump first-ever "$QS_CONFIG_DIR/shell.qml" "2026-03-01 09:00:00"
check "the first crash IS reported"    "$("$CRASH" check | cut -d' ' -f2)" "first-ever"

# Somebody else's crash is not something this shell came back from.
make_dump theirs-later "$HOME/.config/quickshell/somebody/shell.qml" "2026-04-01 09:00:00"
check "their crash is not reported"    "$("$CRASH" check)" ""

# A record that has been corrupted is not a reason to stay silent for ever.
printf 'nonsense\n' > "$seen"
make_dump after-corrupt "$QS_CONFIG_DIR/shell.qml" "2026-05-01 09:00:00"
check "a corrupt record still reports" "$("$CRASH" check | cut -d' ' -f2)" "after-corrupt"

rm -rf "$CRASHES/theirs-later" "$CRASHES/after-corrupt" "$CRASHES/first-ever"
make_dump old-ours "$QS_CONFIG_DIR/shell.qml" "2026-01-01 10:00:00"
make_dump new-ours "$QS_CONFIG_DIR/shell.qml" "2026-01-01 12:00:00"

# --- removal ------------------------------------------------------------------
"$CRASH" remove old-ours >/dev/null 2>&1
check "one dump removed"              "$("$CRASH" list --ids | wc -l)" "1"
"$CRASH" remove --all >/dev/null 2>&1
check "all of ours removed"           "$("$CRASH" list --ids | wc -l)" "0"
check "and theirs left alone"         "$([ -d "$CRASHES/theirs" ] && echo yes)" "yes"

check "no dumps reads cleanly"        "$("$CRASH" list 2>&1 | grep -c 'no crash dumps')" "1"

harness_done
