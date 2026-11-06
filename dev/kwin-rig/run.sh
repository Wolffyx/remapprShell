#!/usr/bin/env bash
# A KWin of its own, to try this project's KWin scripts in -- with nothing on
# the desktop and nothing of the real session touched.
#
#   dev/kwin-rig/run.sh <scenario.sh>      e.g. scenarios/snap.sh
#
# The scenario is sourced inside rig.sh, which starts a headless KWin
# (--virtual) and gives it the helpers rig.sh lists: windows to drag, a
# pointer to drag them with, KWin scripts to load and screenshots of what
# KWin drew. Pictures and the KWin log land in a directory of the run's own
# under build/kwin-rig/ (build/kwin-rig/last is the newest).
#
# Why each part is the way it is:
#
#   dbus-run-session  KWin owns org.kde.KWin; on the real bus that is the
#                     real KWin's. bus.conf names no service directories, so
#                     nothing can be started on it: a portal the first runs
#                     started outlived them and held this script's output
#                     open, so it never returned.
#   timeout -k        a scenario that waits on a drag that never ends should
#                     not hang the terminal.
#   fakeinput         KWin's fake input protocol, so a press, a drag and a
#                     release are KWin's own -- an interactive move KWin
#                     started, which no script can start.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HERE/../.." && pwd)
OUT="$REPO_ROOT/build/kwin-rig"
[ $# -ge 1 ] || { echo "usage: $0 <scenario.sh>" >&2; exit 2; }
scenario=$(realpath "$1")

mkdir -p "$OUT"
if [ ! -x "$OUT/fakeinput" ] || [ "$HERE/fakeinput.c" -nt "$OUT/fakeinput" ]; then
    wayland-scanner client-header "$HERE/fake-input.xml" "$OUT/fake-input-client.h" \
        && wayland-scanner private-code "$HERE/fake-input.xml" "$OUT/fake-input.c" \
        && cc -O1 -I"$OUT" -o "$OUT/fakeinput" "$HERE/fakeinput.c" "$OUT/fake-input.c" \
               $(pkg-config --cflags --libs wayland-client) \
        || { echo "could not build fakeinput (needs a C compiler, wayland-scanner, wayland-client)" >&2; exit 1; }
fi

REPO_ROOT=$REPO_ROOT RIG_OUT=$OUT timeout -k 5 "${RIG_TIMEOUT:-90}" \
    dbus-run-session --config-file="$HERE/bus.conf" -- "$HERE/rig.sh" "$scenario"
