#!/usr/bin/env bash
# Tests the screenshot action against a stand-in desktop portal.
#
# The real portal is part of the running desktop, and asking it for a
# screenshot puts a chooser on the screen of whoever runs the tests. So
# nothing here may reach the session bus at all. Every capture runs under
# `dbus-run-session` on a bus of its own, made from a configuration with no
# service directories -- the stock session one would start the real
# xdg-desktop-portal on it, which would then talk to the real compositor --
# and a stand-in portal answers on it. Outside those buses the session bus
# address points at nothing, so a call that got out would fail rather than
# arrive.
#
# What is checked: that `screen` asks for no chooser and `region` and
# `window` ask for the portal's own, that one connection subscribes, calls and
# hears the answer (the thing a one-shot `gdbus call` cannot do), that the
# file ends up under the pictures directory, and that a cancel, a failure, a
# timeout and no portal at all are each told apart.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

SCREENSHOT="$REPO_ROOT/scripts/screenshot.sh"
HELPER="$REPO_ROOT/scripts/lib/portal-screenshot.py"

# Nothing of the caller's session: no bus to fall back to, no display for a
# stand-in to find, and a runtime directory that is the sandbox's -- GIO looks
# for `$XDG_RUNTIME_DIR/bus` when no address is set.
export DBUS_SESSION_BUS_ADDRESS="unix:path=$SANDBOX/no-bus-here"
export XDG_RUNTIME_DIR="$SANDBOX/run"
mkdir -m 700 -p "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY

# The clipboard and the notification reach the desktop by other roads than
# the bus, so they are written down rather than made.
CALLS="$SANDBOX/calls"
fake_recorders "$CALLS" wl-copy notify-send xdg-user-dir
PICTURES="$HOME/Pictures/Screenshots"

echo "== the helper, with no bus at all =="
out=$(env -u "$NO_SESSION_VAR" python3 "$HELPER" 2>&1); rc=$?
check "no session bus is no portal"      "$rc" "3"
# Without python-gobject the helper cannot reach a bus to find it empty, and
# says that first -- which is what CI's container, with no GObject, sees.
if python3 -c "import gi" 2>/dev/null; then
    contains "and says so"               "$out" "no session bus"
else
    contains "and says so"               "$out" "python-gobject is not installed"
fi
env -u "$NO_SESSION_VAR" python3 "$HELPER" --check >/dev/null 2>&1; rc=$?
check "and --check says the same"        "$rc" "3"
python3 "$HELPER" --timeout soon >/dev/null 2>&1; rc=$?
check "a command line it cannot read"    "$rc" "64"

echo "== with no session =="
check "status says no portal was asked" \
      "$("$SCREENSHOT" status --json | jq -c '[.tool, .session, ([.modes[].supported] | any)]')" '["",false,false]'
out=$("$SCREENSHOT" region 2>&1); rc=$?
check "a capture is refused"             "$rc" "1"
contains "and says why"                  "$out" "no session"

command -v dbus-run-session >/dev/null 2>&1 || { echo "  SKIP  dbus-run-session not available"; harness_done; }
python3 -c "import gi; gi.require_version('Gio','2.0')" 2>/dev/null \
    || { echo "  SKIP  python-gobject not installed"; harness_done; }

# A bus that can start nothing: no <servicedir>, no standard ones.
BUS_CONF="$SANDBOX/bus.conf"
mkdir -p "$SANDBOX/bus"
cat > "$BUS_CONF" <<CONF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:dir=$SANDBOX/bus</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
CONF

# The stand-in: the Screenshot method and its version, answering the way
# FAKE_PORTAL_ANSWER says, and writing down every request it is sent. It
# answers on the path the request was given and to the caller alone, as the
# real one does.
FAKE_PORTAL="$SANDBOX/fake-portal.py"
cat > "$FAKE_PORTAL" <<'PY'
import json, os, gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

answer = os.environ["FAKE_PORTAL_ANSWER"]
log = os.environ["FAKE_PORTAL_LOG"]
picture = os.environ["FAKE_PORTAL_PICTURE"]
PORTAL = """<node>
  <interface name="org.freedesktop.portal.Screenshot">
    <method name="Screenshot">
      <arg type="s" name="parent_window" direction="in"/>
      <arg type="a{sv}" name="options" direction="in"/>
      <arg type="o" name="handle" direction="out"/>
    </method>
    <property name="version" type="u" access="read"/>
  </interface>
</node>"""
REQUEST = """<node>
  <interface name="org.freedesktop.portal.Request">
    <method name="Close"/>
  </interface>
</node>"""
portal, request_node = Gio.DBusNodeInfo.new_for_xml(PORTAL), Gio.DBusNodeInfo.new_for_xml(REQUEST)

def write(entry):
    with open(log, "a") as f:
        f.write(json.dumps(entry) + "\n")

def on_request(conn, sender, path, iface, method, params, invocation):
    write({"closed": path})
    invocation.return_value(None)

def on_call(conn, sender, path, iface, method, params, invocation):
    parent, options = params.unpack()
    token = options.get("handle_token", "")
    handle = f"/org/freedesktop/portal/desktop/request/{sender[1:].replace('.', '_')}/{token}"
    if answer == "elsewhere":          # a portal older than the path rule
        handle = "/org/freedesktop/portal/desktop/request/older/1"
    write({"interactive": options.get("interactive"), "token": token, "parent": parent})
    conn.register_object(handle, request_node.interfaces[0], on_request, None, None)
    invocation.return_value(GLib.Variant("(o)", (handle,)))
    if answer == "silent":
        return
    code = {"ok": 0, "elsewhere": 0, "nouri": 0, "cancel": 1}.get(answer, 2)
    results = {}
    if answer in ("ok", "elsewhere"):
        results["uri"] = GLib.Variant("s", Gio.File.new_for_path(picture).get_uri())
    elif answer == "nouri":
        results["uri"] = GLib.Variant("s", "https://example.invalid/shot.png")
    def respond():
        conn.emit_signal(sender, handle, "org.freedesktop.portal.Request", "Response",
                         GLib.Variant("(ua{sv})", (code, results)))
        return False
    # At once, as a capture with no chooser answers -- which is what makes
    # subscribing after the call too late. Later for the older portal, whose
    # path the caller learns only from the reply.
    GLib.timeout_add(300 if answer == "elsewhere" else 0, respond)

def on_property(conn, sender, path, iface, name):
    return GLib.Variant("u", 2)

def on_bus(conn, name):
    conn.register_object("/org/freedesktop/portal/desktop", portal.interfaces[0],
                         on_call, on_property, None)

def on_name(conn, name):
    open(os.environ["FAKE_PORTAL_READY"], "w").close()

Gio.bus_own_name(Gio.BusType.SESSION, "org.freedesktop.portal.Desktop",
                 Gio.BusNameOwnerFlags.NONE, on_bus, on_name, None)
GLib.MainLoop().run()
PY

export FAKE_PORTAL_LOG="$SANDBOX/portal.log" FAKE_PORTAL_READY="$SANDBOX/portal.ready"
export FAKE_PORTAL_PICTURE="$SANDBOX/portal out/Screenshot from the portal.png"
mkdir -p "$(dirname "$FAKE_PORTAL_PICTURE")"

# on_private_bus <answer|none> <command>...: the command on a bus of its own,
# with the stand-in answering <answer>, or with no portal at all.
#
# The no-session switch is lifted for the command alone, and only once it is
# certain the bus it would reach is the private one: the check is made inside,
# against the address outside, and anything else refuses to run.
on_private_bus() {
    local answer=$1; shift
    : > "$FAKE_PORTAL_LOG"; rm -f "$FAKE_PORTAL_READY"
    printf 'portal bytes' > "$FAKE_PORTAL_PICTURE"
    OUTER_BUS=$DBUS_SESSION_BUS_ADDRESS FAKE_PORTAL_ANSWER=$answer \
    dbus-run-session --config-file="$BUS_CONF" -- bash -c '
        case "$DBUS_SESSION_BUS_ADDRESS" in
            ""|"$OUTER_BUS") echo "not on a private bus" >&2; exit 99 ;;
        esac
        fake=""
        if [ "$FAKE_PORTAL_ANSWER" != none ]; then
            python3 -W ignore::DeprecationWarning "'"$FAKE_PORTAL"'" & fake=$!
            for _ in $(seq 1 100); do [ -f "$FAKE_PORTAL_READY" ] && break; sleep 0.05; done
        fi
        "$@"; rc=$?
        [ -n "$fake" ] && kill "$fake" 2>/dev/null
        exit $rc' _ "$@"
}
# The command with the switch lifted: run inside, after the check.
lifted=(env -u "$NO_SESSION_VAR")
asked() { jq -rs "$1" "$FAKE_PORTAL_LOG"; }
saved() { find "$PICTURES" -type f 2>/dev/null | sort; }
recorded() { local i; for i in $(seq 1 40); do grep -q -- "$1" "$CALLS" && return 0; sleep 0.05; done; return 1; }

echo "== the bus the captures use =="
check "it is not the caller's" \
      "$(on_private_bus none bash -c '[ "$DBUS_SESSION_BUS_ADDRESS" != "$OUTER_BUS" ] && echo private')" "private"
check "and it can start no portal of its own" \
      "$(on_private_bus none gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
          --method org.freedesktop.DBus.ListActivatableNames | grep -c portal)" "0"

echo "== the whole screen: no chooser =="
out=$(on_private_bus ok "${lifted[@]}" "$SCREENSHOT" screen 2>&1); rc=$?
check "it is taken"                      "$rc" "0"
check "without the portal's chooser"     "$(asked '.[0].interactive')" "false"
check "asked once"                       "$(asked 'length')" "1"
check "with a token of its own"          "$(asked '.[0].token' | grep -cE '^[A-Za-z0-9_]+$')" "1"
file=$(saved)
check "saved under the pictures directory" "$(printf '%s\n' "$file" | grep -c "^$PICTURES/Screenshot_[0-9]\{8\}_[0-9]\{6\}\.png$")" "1"
check "the portal's picture, moved there" "$(cat "$file" 2>/dev/null):$([ -e "$FAKE_PORTAL_PICTURE" ] && echo left || echo moved)" "portal bytes:moved"
check "and the path printed"             "$(printf '%s' "$out" | tail -n1)" "$file"
recorded "wl-copy --type image/png"; check "copied to the clipboard" "$?" "0"
recorded "notify-send.*$file";       check "and announced with the file" "$?" "0"
rm -rf "$PICTURES"; : > "$CALLS"

echo "== a region and a window: the portal's own chooser =="
on_private_bus ok "${lifted[@]}" "$SCREENSHOT" region >/dev/null 2>&1; rc=$?
check "a region is taken"                "$rc:$(asked '.[0].interactive')" "0:true"
on_private_bus ok "${lifted[@]}" "$SCREENSHOT" window >/dev/null 2>&1; rc=$?
check "and a window, the same way"       "$rc:$(asked '.[0].interactive')" "0:true"
# Within the same second, which a name made to the second would have had
# the second write over the first.
check "two pictures, neither written over" "$(saved | wc -l)" "2"
rm -rf "$PICTURES"; : > "$CALLS"

# A portal that writes into the pictures directory itself is left alone.
mkdir -p "$PICTURES"
out=$(FAKE_PORTAL_PICTURE="$PICTURES/Named by the portal.png" \
      on_private_bus ok "${lifted[@]}" "$SCREENSHOT" screen 2>/dev/null)
check "a picture already there stays as it is" "$out:$(saved | wc -l)" "$PICTURES/Named by the portal.png:1"
rm -rf "$PICTURES"; : > "$CALLS"

echo "== what the portal answers =="
out=$(on_private_bus cancel "${lifted[@]}" "$SCREENSHOT" region 2>&1); rc=$?
check "a cancel is not a failure"        "$rc" "0"
check "and saves nothing"                "$(saved | wc -l)" "0"
check "or announces anything"            "$(grep -c notify-send "$CALLS")" "0"
out=$(on_private_bus fail "${lifted[@]}" "$SCREENSHOT" screen 2>&1); rc=$?
check "a failure is one"                 "$rc" "1"
contains "and is said"                   "$out" "could not take the screenshot"
out=$(on_private_bus none "${lifted[@]}" "$SCREENSHOT" screen 2>&1); rc=$?
check "no portal at all is refused"      "$rc" "1"
contains "and named"                     "$out" "no desktop portal answers Screenshot"

# The helper's own exit codes, which the script above turns into words.
on_private_bus cancel "${lifted[@]}" python3 "$HELPER" --interactive >/dev/null 2>&1; rc=$?
check "helper: cancelled is 1"           "$rc" "1"
on_private_bus fail "${lifted[@]}" python3 "$HELPER" >/dev/null 2>&1; rc=$?
check "helper: failed is 2"              "$rc" "2"
on_private_bus nouri "${lifted[@]}" python3 "$HELPER" >/dev/null 2>&1; rc=$?
check "helper: no local file is 2"       "$rc" "2"
on_private_bus none "${lifted[@]}" python3 "$HELPER" >/dev/null 2>&1; rc=$?
check "helper: no portal is 3"           "$rc" "3"
on_private_bus silent "${lifted[@]}" python3 "$HELPER" --timeout 1 >/dev/null 2>&1; rc=$?
check "helper: no answer is 4"           "$rc" "4"
check "and the request is closed"        "$(asked 'map(select(.closed)) | length')" "1"
out=$(on_private_bus ok "${lifted[@]}" python3 "$HELPER" 2>/dev/null); rc=$?
check "helper: the uri becomes a path"   "$rc:$out" "0:$FAKE_PORTAL_PICTURE"
out=$(on_private_bus elsewhere "${lifted[@]}" python3 "$HELPER" 2>/dev/null); rc=$?
check "helper: an older portal's path is followed" "$rc:$out" "0:$FAKE_PORTAL_PICTURE"

echo "== status, with a portal =="
s=$(on_private_bus ok "${lifted[@]}" "$SCREENSHOT" status --json)
check "the portal and its version"       "$(jq -c '[.tool, .version]' <<<"$s")" '["portal",2]'
check "every mode"                       "$(jq -c '[.modes[] | select(.supported) | .mode]' <<<"$s")" '["region","screen","window"]'
check "status took no picture"           "$(asked 'length')" "0"

# The switch itself: with it set the portal is not asked, even with one there
# to answer.
echo "== the no-session switch holds on any bus =="
on_private_bus ok "$SCREENSHOT" screen >/dev/null 2>&1; rc=$?
check "refused"                          "$rc" "1"
check "and the portal never heard"       "$(asked 'length')" "0"

harness_done
