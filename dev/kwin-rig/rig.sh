#!/usr/bin/env bash
# The inside of run.sh: run there, under its own session bus, never directly.
#
# Starts a headless KWin with its own configuration, data and Wayland socket,
# sources the scenario with these helpers, and stops KWin again:
#
#   window <title> <w> <h> <colour>   a plain Qt window to drag about
#   kjs <name>                        a one-shot KWin JS script, from stdin
#   geom <title>                      "x y width height" and its tile, or "none"
#   kwin_windows                      how many windows KWin is drawing itself
#   tile <title>                      just the tile, "x,y,width,height" or "none"
#   activate <title>                  make it the active window
#   active                            the active window's title
#   load <kwin/dir> [Key=value...]    render one of this project's KWin
#                                     packages into the rig, set keys in its
#                                     kwinrc group, and load it
#   input_start / send <cmd>... / input_stop
#                                     one fake pointer for the scenario:
#                                     "move X Y", "down", "up", "sleep MS",
#                                     "glide X1 Y1 X2 Y2 STEPS MS", "key CODE",
#                                     "press CODE", "release CODE" (Linux
#                                     key codes: Escape 1, Enter 28, Meta 125)
#   click <x> <y>                     press and let go there
#   drag <title> <x> <y> [cmd...]     press a window's title bar, carry it to
#                                     x,y, run any commands, let go
#   shot <name>                       KWin's own screenshot, into the run's
#                                     directory
#   windows_stub                      a stand-in window daemon on the rig's
#                                     bus, for kwin/windows to report to
#   taskbar                           the titles in the last list it was
#                                     sent, one line, as the taskbar has them
#   check <what> <got> <want>         a line of the scenario's verdict
#
# A scenario that needs KWin's global shortcuts -- kglobalaccel, which KWin
# runs inside itself -- says so in a line of its own, `# rig: global-shortcuts`.
# They are off otherwise, as they were for the first scenarios. Either way
# the shortcut server is this KWin's, on this bus, reading this rig's own
# kglobalshortcutsrc.
#
# KWin draws its windows with QtQuick's software renderer here: the virtual
# backend has no buffers for KWin's own windows to render into, and without
# it KWin aborts the moment a script shows one.
set -uo pipefail
RIG=$(cd "$(dirname "$0")" && pwd)
OUT=${RIG_OUT:?run this through run.sh}
# A directory of its own for every run: two sessions ran scenarios at once
# on 2026-10-17, each wiping the one directory they shared, and each got the
# other's windows and failures that were not theirs. build/kwin-rig/last
# points at the newest.
RUN=$(mktemp -d "$OUT/run.XXXXXX")
mkdir -p "$RUN"/{config,data,cache,state,home}
ln -sfn "$(basename "$RUN")" "$OUT/last"
export HOME=$RUN/home XDG_CONFIG_HOME=$RUN/config XDG_DATA_HOME=$RUN/data \
       XDG_CACHE_HOME=$RUN/cache XDG_STATE_HOME=$RUN/state
unset DISPLAY WAYLAND_DISPLAY WAYLAND_SOCKET
export KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 KWIN_SCREENSHOT_NO_PERMISSION_CHECKS=1 \
       QT_LOGGING_RULES="js.debug=true;kwin_scripting.debug=true;qml.debug=true" \
       QT_FORCE_STDERR_LOGGING=1 GIO_USE_VFS=local GTK_USE_PORTAL=0

SOCK=kwin-rig-$$
shortcuts=--no-global-shortcuts
grep -qx '# rig: global-shortcuts' "$1" && shortcuts=
# shellcheck disable=SC2086  # $shortcuts is one flag or none
QT_QUICK_BACKEND=software kwin_wayland --virtual --socket "$SOCK" \
    --width "${RIG_W:-1920}" --height "${RIG_H:-1080}" \
    --no-lockscreen $shortcuts --no-kactivities > "$RUN/kwin.log" 2>&1 &
KWIN=$!
trap 'kill $(jobs -p) 2>/dev/null' EXIT
for _ in $(seq 100); do [ -S "$XDG_RUNTIME_DIR/$SOCK" ] && break; sleep 0.1; done
[ -S "$XDG_RUNTIME_DIR/$SOCK" ] || { echo "KWin did not start:"; cat "$RUN/kwin.log"; exit 1; }
export WAYLAND_DISPLAY=$SOCK QT_QPA_PLATFORM=wayland
sleep 1

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"

scripting() { qdbus6 org.kde.KWin /Scripting "org.kde.kwin.Scripting.$1" "${@:2}"; }

kjs() {
    local f=$RUN/$1.js
    cat > "$f"
    scripting loadScript "$f" "$1" >/dev/null
    scripting start >/dev/null
    sleep 0.3
    scripting unloadScript "$1" >/dev/null
}

window() {
    printf 'import QtQuick\nimport QtQuick.Window\nWindow { title: "%s"; width: %d; height: %d; visible: true; color: "%s" }\n' \
        "$1" "$2" "$3" "$4" > "$RUN/$1.qml"
    QT_QPA_PLATFORMTHEME=generic qml6 "$RUN/$1.qml" > "$RUN/$1.client.log" 2>&1 &
    sleep 1.2
}

geom() {
    local tag="GEOM$RANDOM"
    kjs geom <<JS
for (const w of workspace.windowList()) if (w.caption === "$1") {
    const g = w.frameGeometry, t = w.tile ? w.tile.absoluteGeometry : null;
    print("$tag " + [g.x, g.y, g.width, g.height].map(Math.round).join(" ")
          + " " + (t ? [t.x, t.y, t.width, t.height].map(Math.round).join(",") : "none"));
}
JS
    sleep 0.2
    grep -a "$tag " "$RUN/kwin.log" | tail -1 | sed "s/.*$tag //"
}

tile() { geom "$1" | cut -d' ' -f5; }

activate() {
    kjs activate <<JS
for (const w of workspace.windowList()) if (w.caption === "$1") workspace.activeWindow = w;
JS
}

active() {
    local tag="ACTIVE$RANDOM"
    kjs active <<JS
print("$tag " + (workspace.activeWindow ? workspace.activeWindow.caption : "none"));
JS
    sleep 0.2
    grep -a "$tag " "$RUN/kwin.log" | tail -1 | sed "s/.*$tag //"
}

load() {   # <kwin/dir> [Key=value...]
    local src=$REPO_ROOT/$1 id api main kv meta; shift
    meta=$(mktemp)
    render_template "$src/metadata.json.in" "$meta" >/dev/null && id=$(jq -r .KPlugin.Id "$meta")
    rm -f "$meta"
    [ -n "${id:-}" ] && [ "$id" != null ] || { echo "no plugin id in $src/metadata.json.in"; return 1; }
    kwin_package_render "$src" "$XDG_DATA_HOME/kwin/scripts/$id" "$id" || return 1
    for kv in "$@"; do
        kwriteconfig6 --file kwinrc --group "Script-$id" --key "${kv%%=*}" "${kv#*=}"
    done
    # Enabled, as an install enables it: KWin's Scripting::start() -- run by
    # every one-shot's `start` and by every reconfigure, a saved tile layout
    # among them -- unloads any installed script kwinrc does not enable. The
    # snap script vanished mid-scenario that way, and every drag after it
    # went unseen.
    kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" true
    api=$(jq -r '."X-Plasma-API"' "$XDG_DATA_HOME/kwin/scripts/$id/metadata.json")
    main="$XDG_DATA_HOME/kwin/scripts/$id/contents/$(jq -r '."X-Plasma-MainScript"' "$XDG_DATA_HOME/kwin/scripts/$id/metadata.json")"
    scripting unloadScript "$id" >/dev/null
    if [ "$api" = declarativescript ]; then
        scripting loadDeclarativeScript "$main" "$id" >/dev/null
    else
        scripting loadScript "$main" "$id" >/dev/null
    fi
    scripting start >/dev/null
    sleep 0.8
}

# One fake pointer for the whole scenario: KWin lets go of a fake device's
# buttons when its client goes, so a drag must not span two of them.
input_start() { mkfifo "$RUN/input.fifo"; "$OUT/fakeinput" < "$RUN/input.fifo" & exec 9> "$RUN/input.fifo"; }
send() { printf '%s\n' "$@" >&9; }
input_stop() { exec 9>&-; }

# The title bar, a fraction of the way along it (GRAB, percent; the middle by
# default) -- off the middle when another window's edge is there.
titlebar() {
    local x y w
    read -r x y w _ <<< "$(geom "$1")"
    echo "$(( x + w * ${GRAB:-50} / 100 )) $(( y + 12 ))"
}

drag() {   # <title> <x> <y> [cmd...]
    local title=$1 x=$2 y=$3 tx ty
    shift 3
    read -r tx ty <<< "$(titlebar "$title")"
    send "move $tx $ty" "sleep 60" "down" "sleep 60" \
         "glide $tx $ty $x $((y + 200)) 10 10" "glide $x $((y + 200)) $x $y 10 10" "sleep 150" \
         "$@" "up" "sleep 400"
    sleep 1.6
}

click() { send "move $1 $2" "sleep 60" "down" "sleep 40" "up" "sleep 300"; sleep 0.6; }

shot() { python3 -I "$RIG/shot.py" "$RUN/$1.png" > /dev/null && echo "  picture: ${RUN#"$REPO_ROOT"/}/$1.png"; }

# How many of KWin's own windows are up -- no process, no class: a panel a
# script is showing, KWin's outline.
kwin_windows() {
    local tag="KWINOWN$RANDOM"
    kjs kwinown <<JS
print("$tag " + workspace.windowList().filter(w => w.pid === -1 && !w.resourceClass).length);
JS
    sleep 0.2
    grep -a "$tag " "$RUN/kwin.log" | tail -1 | sed "s/.*$tag //"
}

windows_stub() {
    python3 -I "$RIG/windowsd-stub.py" "$DBUS_NAME" "$RUN/windows.jsonl" &
    sleep 0.5
}

taskbar() {
    sleep 0.3
    tail -1 "$RUN/windows.jsonl" 2>/dev/null | jq -r '[.[] | if .title == "" then "<untitled>" else .title end] | sort | join(" ")'
}

passed=0 failed=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"; passed=$((passed + 1))
    else
        printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2"; failed=$((failed + 1))
    fi
}

source "$1"

if grep -a -E 'TypeError|ReferenceError|failed to load|Component failed' "$RUN/kwin.log" >/dev/null; then
    echo "  KWin's log has script errors:"
    grep -a -E 'TypeError|ReferenceError|failed to load|Component failed' "$RUN/kwin.log" | head -5 | sed 's/^/    /'
    failed=$((failed + 1))
fi
echo "$passed passed, $failed failed (KWin's log: ${RUN#"$REPO_ROOT"/}/kwin.log)"
[ "$failed" = 0 ]
