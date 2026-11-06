#!/usr/bin/env bash
# Tests the daylight helper: KDE's schedule first, the sun here when KDE has
# none or has lost its location.
#
# Nothing here may reach a real bus. KNightTime and KWin live on the session
# bus and GeoClue on the system bus, and asking either one would answer with
# this machine's own schedule and place -- different on every machine, and
# the place is somebody's home. Both bus addresses point at nothing, so a
# call that got out would fail rather than arrive. The arithmetic -- the sun,
# the schedule, the fallback check -- is asked of the module directly, at a
# fixed time and in UTC, so it answers the same everywhere.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

HELPER="$REPO_ROOT/scripts/lib/daylight.py"

export DBUS_SESSION_BUS_ADDRESS="unix:path=$SANDBOX/no-bus-here"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$SANDBOX/no-system-bus-here"
export XDG_RUNTIME_DIR="$SANDBOX/run"
mkdir -m 700 -p "$XDG_RUNTIME_DIR"
export TZ=UTC

# One expression of the module, printed.
py() {
    python3 -c "import sys; sys.path.insert(0, '$REPO_ROOT/scripts/lib'); import daylight as d; print($1)"
}

# 2026-06-21 12:00 UTC, and the same day at midnight.
NOON=1782043200000
MIDNIGHT=1782000000000

echo "== the sun =="
# Lisbon at midsummer: up at noon, down at midnight, setting a little after
# 20:00 UTC (21:0x in summer time) and rising a little after 05:00 UTC.
check "up at noon in Lisbon"              "$(py "d.is_up(38.72, -9.14, $NOON)")" "True"
check "down at midnight"                  "$(py "d.is_up(38.72, -9.14, $MIDNIGHT)")" "False"
check "sets at 20:0x"                     "$(py "d.clock(d.next_change(38.72, -9.14, $NOON))[:4]")" "20:0"
check "rises at 05:5x or 06:0x"           "$(py "d.clock(d.next_change(38.72, -9.14, $MIDNIGHT))[:2] in ('05', '06')")" "True"
# Tromsø at midsummer: the sun never sets, and there is nothing to find.
check "a polar summer has no sunset"      "$(py "d.next_change(69.65, 18.96, $NOON)")" "0"
check "and the sun is up all night"       "$(py "d.is_up(69.65, 18.96, $MIDNIGHT)")" "True"

echo "== KDE's schedule =="
# Cycles are (noon, morning start, morning end, evening start, evening end).
REAL="[(0, $MIDNIGHT + 21345678, $MIDNIGHT + 23145678, $MIDNIGHT + 72612345, $MIDNIGHT + 74412345)]"
FALLBACK="[(0, $MIDNIGHT + 6*3600000, $MIDNIGHT + 6*3600000 + 1800000, $MIDNIGHT + 18*3600000, $MIDNIGHT + 18*3600000 + 1800000)]"
check "day between the transitions"       "$(py "d.schedule_answer($REAL, $NOON)")" "(True, $((MIDNIGHT + 72612345)))"
check "night before the morning"          "$(py "d.schedule_answer($REAL, $MIDNIGHT)[0]")" "False"
check "a real sunset is a real sunset"    "$(py "d.lost_location($REAL, ('Location', True, '06:00:00', '18:00:00'))")" "False"
check "the fallback times are noticed"    "$(py "d.lost_location($FALLBACK, ('Location', True, '06:00:00', '18:00:00'))")" "True"
check "times the user chose stand"        "$(py "d.lost_location($FALLBACK, ('Times', True, '06:00:00', '18:00:00'))")" "False"
check "a location the user typed stands"  "$(py "d.lost_location($FALLBACK, ('Location', False, '06:00:00', '18:00:00'))")" "False"
check "fallback times of their own too"   "$(py "d.lost_location($FALLBACK, ('Location', True, '07:00:00', '19:00:00'))")" "False"

cat > "$SANDBOX/knighttimerc" <<'EOF'
[General]
Source=Times

[Times]
SunriseStart=07:30:00
SunsetStart=19:15:00
EOF
check "knighttimerc is read"              "$(py "d.knighttime_config('$SANDBOX/knighttimerc')")" "('Times', True, '07:30:00', '19:15:00')"
check "and missing is KDE's defaults"     "$(py "d.knighttime_config('$SANDBOX/nothing-here')")" "('Location', True, '06:00:00', '18:00:00')"

echo "== places =="
check "coordinates are read"              "$(py "d.coordinates(' 46.77, 23.60 ')")" "(46.77, 23.6)"
check "nonsense is no place"              "$(py "d.coordinates('north')")" "None"
check "nor is a place off the globe"      "$(py "d.coordinates('91,0')")" "None"

echo "== the command, with no bus at all =="
out=$(python3 "$HELPER" --now "$NOON" 2>/dev/null); rc=$?
check "nothing knows"                     "$rc" "3"
check "and says so"                       "$(jq -c '[.known, .source]' <<< "$out")" '[false,""]'
out=$(python3 "$HELPER" --now "$NOON" --coordinates "38.72,-9.14" 2>/dev/null); rc=$?
check "typed coordinates answer"          "$rc" "0"
check "with the sun's answer"             "$(jq -c '[.known, .daylight, .source, .location]' <<< "$out")" '[true,true,"shell","coordinates"]'
# Without python-gobject the helper cannot reach a bus to find KDE missing,
# and says that first -- which is what CI's container, with no GObject, sees.
if python3 -c "import gi" 2>/dev/null; then
    contains "and why KDE was passed over" "$(jq -r .why <<< "$out")" "night time service"
else
    contains "and why KDE was passed over" "$(jq -r .why <<< "$out")" "python-gobject is not installed"
fi

CACHE="$SANDBOX/state/daylight-place.json"
mkdir -p "$(dirname "$CACHE")"
printf '{"latitude": 38.72, "longitude": -9.14}' > "$CACHE"
out=$(python3 "$HELPER" --now "$MIDNIGHT" --cache "$CACHE" --coordinates "69.65,18.96" 2>/dev/null)
check "the kept place beats coordinates"  "$(jq -c '[.daylight, .location]' <<< "$out")" '[false,"cache"]'
out=$(python3 "$HELPER" --now "$NOON" --prefer shell --coordinates "38.72,-9.14" 2>/dev/null)
contains "--prefer shell skips KDE"       "$(jq -r .why <<< "$out")" "theme.daylight.source is shell"

out=$(python3 "$HELPER" --now "$NOON" --no-bus --coordinates "38.72,-9.14" 2>/dev/null)
contains "--no-bus asks nobody"           "$(jq -r .why <<< "$out")" "no session to ask KDE in"

echo "== --locate: the OS's place, for the weather =="
out=$(python3 "$HELPER" --locate --no-bus 2>/dev/null); rc=$?
check "no OS and nothing kept is no place" "$rc" "3"
out=$(python3 "$HELPER" --locate --no-bus --cache "$CACHE" --coordinates "69.65,18.96" 2>/dev/null); rc=$?
check "the kept place answers"            "$rc" "0"
check "and typed coordinates are not its" "$(jq -c '[.known, .latitude, .location]' <<< "$out")" '[true,38.72,"cache"]'

python3 "$HELPER" --prefer gnome >/dev/null 2>&1; rc=$?
check "a source it does not know"         "$rc" "64"
python3 "$HELPER" --timeout soon >/dev/null 2>&1; rc=$?
check "a timeout that is not a number"    "$rc" "64"
python3 "$HELPER" --now >/dev/null 2>&1; rc=$?
check "a flag with no value"              "$rc" "64"

harness_done
