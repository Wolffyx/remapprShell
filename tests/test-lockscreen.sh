#!/usr/bin/env bash
# Tests the lock screen commands inside a throwaway HOME, against a stand-in
# for Plasma's greeter.
#
# The real greeter is never run by this suite: `try` with the real one takes
# the keyboard on every screen. `make test` loads the real lock screen in the
# real greeter separately, offscreen and off the bus, with `lockscreen check`.
#
# The scripts run from a copy of the repository, so the lock screen's source
# can be changed after it was tried without touching the real one.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
export XDG_CONFIG_DIRS="$SANDBOX/etc"

REPO="$SANDBOX/repo"
mkdir -p "$REPO/theme"
cp -a "$REPO_ROOT/scripts" "$REPO_ROOT/branding.json" "$REPO/"
cp -a "$REPO_ROOT/VERSION" "$REPO/" 2>/dev/null || true
cp -a "$REPO_ROOT/theme/lockscreen" "$REPO/theme/"

CALLS="$SANDBOX/session-calls"
fake_recorders "$CALLS" qdbus6 busctl systemctl kquitapp6
# The way back names the session and its terminal; read-only, but not this
# machine's to answer.
cat > "$FAKEBIN/loginctl" <<'EOF'
#!/bin/sh
case "$*" in
    *VTNr*) echo 2 ;;
    *Display*) echo 7 ;;
esac
EOF
chmod +x "$FAKEBIN/loginctl"
export "${ENV_PREFIX}_LOCKSCREEN_SETTLE=0"
unset XDG_SESSION_ID

# The stand-in greeter. What it does is read from a file, so a test can change
# it between calls: say ready, fail to load, lack something, complain about a
# file, die, or -- when it has a display, which only `try` gives it -- be
# unlocked, be closed, or never be unlocked.
GREETER="$FAKEBIN/kscreenlocker_greet"
MODE="$SANDBOX/greeter-mode"
GCALLS="$SANDBOX/greeter-calls"; : > "$GCALLS"
cat > "$GREETER" <<EOF
#!/usr/bin/env bash
printf '%s|platform=%s|bus=%s|display=%s\n' "\$*" "\${QT_QPA_PLATFORM:-}" "\${DBUS_SESSION_BUS_ADDRESS:+set}" "\${WAYLAND_DISPLAY:-}" >> "$GCALLS"
shell=""; testing=0
while [ \$# -gt 0 ]; do
    case "\$1" in --testing) testing=1 ;; --shell) shell=\$2; shift ;; esac
    shift
done
[ "\$testing" = 1 ] || { echo "refusing to lock for real" >&2; exit 3; }
mode=\$(cat "$MODE")
if [ -n "\${WAYLAND_DISPLAY:-}" ]; then
    case "\$mode" in
        unlock) echo Unlocked; exit 0 ;;
        close)  exit 1 ;;
        hang)   exec sleep 30 ;;
    esac
fi
ready() {
    grep -q LockScreenUnderTest "\$shell/contents/lockscreen/LockScreen.qml" 2>/dev/null \
        || echo "qml: lock screen: sent a password with nobody there"
    [ -f "\$shell/contents/lockscreen/LockScreen.qml" ] \
        && jq -e '."X-Plasma-APIVersion" == "2"' "\$shell/metadata.json" >/dev/null \
        && echo "qml: lock screen: ready"
}
case "\$mode" in
    broken)
        echo "kscreenlocker_greet: Failed to load lockscreen QML, falling back to built-in locker"
        echo "kscreenlocker_greet: file://\$shell/contents/lockscreen/LockUi.qml:232:17: Kirigami.Avatar is not a type"
        ;;
    lacks)
        echo "qml: lock screen: this greeter lacks respond -- drawing Plasma's own lock screen instead"
        ;;
    autostart)
        ready
        echo "qml: lock screen: started authenticating with nobody there"
        ;;
    warns)
        ready
        echo "file://\$shell/contents/lockscreen/LockUi.qml:10: TypeError: Cannot read property 'x' of null"
        ;;
    dies)
        exit 1
        ;;
    *)
        ready
        ;;
esac
exec sleep 30
EOF
chmod +x "$GREETER"
export "${ENV_PREFIX}_GREETER=$GREETER"
setmode() { printf '%s\n' "$1" > "$MODE"; }

LS="$REPO/scripts/lockscreen.sh"
ls_() { "$LS" "$@" 2>&1; }
ok() { "$LS" "$@" >/dev/null 2>&1 && echo ran || echo refused; }
status() { "$LS" status --json 2>/dev/null; }
js() { status | jq -r "$1"; }
# `try` is the one command that needs the desktop; it is given a stand-in
# display, and the stand-in greeter is all that could reach it.
try_() { env -u "$NO_SESSION_VAR" WAYLAND_DISPLAY=fake "$LS" try "$@" < /dev/null 2>&1; }
src_hash() { (cd "$1" && find . -type f ! -name '.installed-by-*' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) | sha256sum | cut -c1-16; }

QS_PKG="$PLASMA_SHELLS_DIR/$SHELL_PACKAGE_ID"
PL_PKG="$PLASMA_SHELLS_DIR/$PLASMA_SHELL_PACKAGE_ID"
STATE="$STATE_DIR/lockscreen"

echo "== status, fresh =="
# One read for the checks against one state: each read is a third of a second.
s=$(status)
check "nothing tried"          "$(jq -r .tried <<<"$s")" "null"
check "not enabled"            "$(jq -r .enabled <<<"$s")" "false"
check "Plasma's is drawn"      "$(jq -r .drawn <<<"$s")" "plasma"
check "the source is hashed"   "$(jq -r .source <<<"$s")" "$(src_hash "$REPO/theme/lockscreen")"

echo "== check =="
setmode ready
check "loads"                              "$(ok check)" "ran"
last=$(tail -1 "$GCALLS")
contains "in testing mode, from a package path" "$last" "--testing --shell /"
contains "offscreen"                        "$last" "platform=offscreen"
contains "with no session bus"              "$last" "bus=|"
contains "and no display"                   "$last" "display="
setmode broken
out=$(ls_ check)
check "refused when the greeter falls back" "$(ok check)" "refused"
contains "says so"                          "$out" "drew its own built-in locker"
contains "names the file and the line"      "$out" "LockUi.qml:232:17: Kirigami.Avatar is not a type"
setmode lacks
contains "a greeter lacking something"      "$(ls_ check)" "this greeter lacks respond"
setmode warns
out=$(ls_ check)
check "a complaint about our file fails it" "$(ok check)" "refused"
contains "and is shown"                     "$out" "TypeError"
setmode dies
contains "a greeter that exits by itself"   "$(ls_ check)" "exited by itself"
setmode autostart
out=$(ls_ check)
check "a prompt that wakes by itself fails it" "$(ok check)" "refused"
contains "and says why"                     "$out" "with nobody at the keyboard"

echo "== enable, before any try =="
setmode ready
check "refused"        "$(ok enable)" "refused"
contains "says to try" "$(ls_ enable)" "lockscreen try"

echo "== try =="
check "refused with the session off-limits" "$(ok try)" "refused"
check "refused with no display"             "$(env -u "$NO_SESSION_VAR" -u WAYLAND_DISPLAY -u DISPLAY "$LS" try < /dev/null >/dev/null 2>&1 && echo ran || echo refused)" "refused"

setmode broken
before=$(wc -l < "$GCALLS")
out=$(try_)
contains "not shown when it does not load"   "$out" "not showing it"
check "the greeter was only asked offscreen" "$(tail -n +"$((before + 1))" "$GCALLS" | grep -c 'display=fake')" "0"
check "nothing recorded"                     "$([ -e "$STATE/tried.json" ] && echo yes || echo no)" "no"

setmode close
out=$(try_)
contains "closed without unlocking"  "$out" "without unlocking"
check "nothing recorded"             "$([ -e "$STATE/tried.json" ] && echo yes || echo no)" "no"

setmode hang
out=$(export "${ENV_PREFIX}_LOCKSCREEN_TRY_SECONDS=1"; try_)
contains "ends by itself"            "$out" "not unlocked within 1 seconds"
check "nothing recorded"             "$([ -e "$STATE/tried.json" ] && echo yes || echo no)" "no"

setmode unlock
out=$(try_)
contains "unlocked"                       "$out" "is tried"
check "recorded, with the build"          "$(jq -r .hash "$STATE/tried.json")" "$(src_hash "$REPO/theme/lockscreen")"
check "and the greeter"                   "$(jq -r .greeter "$STATE/tried.json")" "$(sha256sum "$GREETER" | cut -c1-16)"
check "the tried copy is the source"      "$(diff -r "$REPO/theme/lockscreen" "$STATE/tried" >/dev/null && echo same || echo differs)" "same"
contains "shown for real, with a display" "$(tail -1 "$GCALLS")" "display=fake"
check "status agrees"                     "$(js '"\(.triedIsSource),\(.triedWithThisGreeter)"')" "true,true"

echo "== enable =="
check "refused with no shell package to put it in" "$(ok enable)" "refused"
mkdir -p "$QS_PKG/contents" "$PL_PKG/contents"
out=$(ls_ enable)
s=$(status)
check "enabled"                         "$(jq -r .enabled <<<"$s")" "true"
check "in both packages"                "$(jq -r '[.packages[] | select(.installed)] | length' <<<"$s")" "2"
check "the copy is the tried one"       "$(diff -r -x '.installed-by-*' "$STATE/tried" "$QS_PKG/contents/lockscreen" >/dev/null && echo same || echo differs)" "same"
check "marked as ours"                  "$(cat "$QS_PKG/contents/lockscreen/.installed-by-$SLUG")" "$(jq -r .hash "$STATE/tried.json")"
contains "gives the way back"           "$out" "loginctl unlock-session 7"
contains "and the terminal to return to" "$out" "Ctrl+Alt+F2"
contains "and the command"              "$out" "lockscreen disable"
check "not drawn while plasmashell is on another package" "$(jq -r .drawn <<<"$s")" "plasma"
kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage "$SHELL_PACKAGE_ID"
check "drawn once it is on ours"        "$(js .drawn)" "ours"

echo "== the source changes after trying =="
printf '\n// changed\n' >> "$REPO/theme/lockscreen/LockUi.qml"
check "status sees it"                  "$(js .triedIsSource)" "false"
out=$(ls_ enable)
contains "enable warns"                 "$out" "the copy that was tried is what is on"
check "and installs the tried copy"     "$(diff -r -x '.installed-by-*' "$STATE/tried" "$QS_PKG/contents/lockscreen" >/dev/null && echo same || echo differs)" "same"

echo "== the greeter changes =="
cp -a "$GREETER" "$SANDBOX/greeter.orig"
printf '# updated\n' >> "$GREETER"
check "status sees it"                  "$(js .triedWithThisGreeter)" "false"
check "enable is refused"               "$(ok enable)" "refused"
contains "and says to try again"        "$(ls_ enable)" "greeter has changed"
cp -a "$SANDBOX/greeter.orig" "$GREETER"

echo "== a lock screen that is not ours =="
rm "$PL_PKG/contents/lockscreen/.installed-by-$SLUG"
check "enable will not replace it"      "$(ok enable)" "refused"
check "status knows"                    "$(js '.packages[] | select(.id == "'"$PLASMA_SHELL_PACKAGE_ID"'") | .foreign')" "true"

echo "== disable, from a console =="
# What a text console has: a HOME and a PATH. No display, no bus, none of
# this suite's settings.
out=$(env -i HOME="$HOME" PATH="$PATH" "$LS" disable 2>&1)
s=$(status)
check "off"                             "$(jq -r .enabled <<<"$s")" "false"
check "gone from ours"                  "$([ -e "$QS_PKG/contents/lockscreen" ] && echo there || echo gone)" "gone"
check "the foreign one left alone"      "$([ -e "$PL_PKG/contents/lockscreen" ] && echo there || echo gone)" "there"
contains "and said so"                  "$out" "not ours; left alone"
check "Plasma's is drawn again"         "$(jq -r .drawn <<<"$s")" "plasma"
check "the rest of the package is untouched" "$([ -d "$QS_PKG/contents" ] && echo there || echo gone)" "there"

echo "== a package installed afresh =="
rm -rf "$PL_PKG/contents/lockscreen"
ls_ enable >/dev/null
rm -rf "$QS_PKG"
mkdir -p "$QS_PKG/contents"
(
    REPO_ROOT="$REPO"
    source "$REPO/scripts/lib/brand.sh"
    source "$REPO/scripts/lib/lockscreen.sh"
    lockscreen_enabled && lockscreen_install_into "$SHELL_PACKAGE_ID"
)
check "gets the lock screen back"       "$(js '.packages[] | select(.id == "'"$SHELL_PACKAGE_ID"'") | .installed')" "true"

echo "== how it looks =="
# The look is kept in two places, because the greeter reads two. Plasma's own
# settings go to kscreenlockerrc under the group its config loader actually
# reads -- [Greeter][LnF][General], found by asking the real greeter what it
# got -- and through the ledger. This shell's own go to a file of its own,
# because the greeter's config object is built from the desktop package's
# config.xml and a key of ours added there never arrives.
plasmakey() { kread kscreenlockerrc Greeter LnF General "$1"; }
ourkey() { kread "$XDG_CONFIG_HOME/$SLUG/lockscreen.conf" Lock "$1"; }
lookval() { "$LS" status --json | jq -r --arg id "$1" '.look[] | select(.id == $id) | .value'; }

check "an unknown setting is refused"    "$("$LS" set nosuch left >/dev/null 2>&1; echo $?)" "1"
check "the clock takes left or center"   "$("$LS" set clock sideways >/dev/null 2>&1; echo $?)" "1"
check "the blur takes a number in range" "$("$LS" set blur 400 >/dev/null 2>&1; echo $?)" "1"
check "and nothing was written"          "$(ourkey clockPosition)" "<unset>"

"$LS" set clock center >/dev/null
check "ours goes in our own file"        "$(ourkey clockPosition)" "center"
check "and not into Plasma's"            "$(plasmakey clockPosition)" "<unset>"
check "read back"                        "$(lookval clock)" "center"
"$LS" set blur 0 >/dev/null
check "the blur is written"              "$(ourkey wallpaperBlur)" "0"
check "zero is kept, not taken as unset" "$(lookval blur)" "0"

"$LS" set media false >/dev/null
check "Plasma's key goes to Plasma"      "$(plasmakey showMediaControls)" "false"
# hideClockWhenIdle is Plasma's and asks the opposite question.
"$LS" set idleClock false >/dev/null
check "an inverted key is stored inverted" "$(plasmakey hideClockWhenIdle)" "true"
check "and read back as it was set"        "$(lookval idleClock)" "false"
check "defaults where nothing is set"      "$(lookval session)" "true"

# The turn-3 and turn-4 styles, and what came with them.
"$LS" set style kiosk >/dev/null
check "a new style is a style"             "$(ourkey style)" "kiosk"
check "the accent takes a name"            "$("$LS" set accent '#ff0000' >/dev/null 2>&1; echo $?)" "1"
"$LS" set accent green >/dev/null
check "and is written by name"             "$(ourkey accent)" "green"
check "dimming takes seconds in range"     "$("$LS" set dim 9000 >/dev/null 2>&1; echo $?)" "1"
"$LS" set dim 0 >/dev/null
check "zero dims never, and is kept"       "$(lookval dim)" "0"
check "hibernating stops at ten percent"   "$("$LS" set hibernateAt 50 >/dev/null 2>&1; echo $?)" "1"
"$LS" set kioskName "Riverside Library · 2nd floor" >/dev/null
check "text is kept as written"            "$(lookval kioskName)" "Riverside Library · 2nd floor"
check "text takes one line"                "$("$LS" set kioskNote $'one\ntwo' >/dev/null 2>&1; echo $?)" "1"
check "and a sensible length"              "$("$LS" set kioskNote "$(printf 'x%.0s' {1..121})" >/dev/null 2>&1; echo $?)" "1"
"$LS" set kioskName "" >/dev/null
check "and can be emptied"                 "$(lookval kioskName)" ""
check "only Plasma's keys are ledgered"    "$(ledger_count lockscreen)" "2"

echo "== nothing reached the session =="
check "no DBus call, restart or quit" "$(cat "$CALLS")" ""

harness_done
