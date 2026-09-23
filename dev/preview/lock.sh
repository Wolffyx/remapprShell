#!/usr/bin/env bash
# Draws the lock screen offscreen, in Plasma's real greeter.
#
#   lock.sh <out.png> [idle|prompt] [delay-ms] [config-json] [WxH]
#
# Nothing locks and nothing reaches PAM: the greeter runs in testing mode with
# no display, no session bus and no runtime directory, and its authenticator is
# replaced by a stand-in that complains rather than authenticating. The config
# JSON overrides the greeter's own settings for the picture only -- the user's
# kscreenlockerrc is never written -- and its "options" object does the same
# for this shell's own, e.g. '{"options": {"style": "minimal"}}'. A "simulate"
# object puts the frame in a state nobody can wait for offscreen:
#   {"simulate": {"battery": {"percent": 4}, "lockout": 540, "dim": true, "leave": 0.4}}
#
# The size matters more here than anywhere else in this directory. Qt's
# offscreen platform invents an 800x800 screen, and every one of these designs
# is drawn for 1920x1080 -- so a picture taken at the default was a picture of
# the fallback scaling, not of the design. The plugin takes a screen
# configuration file, and that is what the last argument writes.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(cd "$HERE/../.." && pwd)
out=$(realpath -m "$1"); state=${2:-prompt}; delay=${3:-2500}; cfg=${4:-'{}'}
size=${5:-1920x1080}
sw=${size%%x*}; sh=${size##*x}

source "$WT/scripts/lib/log.sh"
source "$WT/scripts/lib/brand.sh"
source "$WT/scripts/lib/render.sh"
source "$WT/scripts/lib/lockscreen.sh"

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
pkg="$work/package"
dir="$pkg/contents/lockscreen"
lockscreen_package "$pkg" "${LOCK_SRC:-$WT/theme/lockscreen}" || { echo "could not build the package"; exit 1; }
mv "$dir/LockScreen.qml" "$dir/LockScreenUnderTest.qml"

# This shell's own settings -- the style above all -- are read from a file,
# not from `config`. A config JSON carrying "options" draws with those instead
# of the person's own, from a copy the package is pointed at, so a picture of
# every style never means writing their lockscreen.conf seven times.
if jq -e '.options' <<< "$cfg" >/dev/null 2>&1; then
    { echo "[Lock]"; jq -r '.options | to_entries[] | "\(.key)=\(.value)"' <<< "$cfg"; } > "$work/lockscreen.conf"
    sed -i "s|location: \"file://[^\"]*\"|location: \"file://$work/lockscreen.conf\"|" "$dir/Options.qml"
    cfg=$(jq -c 'del(.options)' <<< "$cfg")
fi
printf 'LockScreenUnderTest 1.0 LockScreenUnderTest.qml\n' >> "$dir/qmldir"

cat > "$dir/LockScreen.qml" <<'QML'
// Written by dev/preview/lock.sh; never installed.
// qmllint disable unqualified
import QtQuick

Item {
    id: probe

    property bool viewVisible: true

    readonly property var overrides: JSON.parse(Qt.application.arguments.length >= 0
        ? (typeof PREVIEW_CONFIG !== "undefined" ? PREVIEW_CONFIG : "{}") : "{}")

    QtObject {
        id: stand
        property int state: 0
        property bool hadPrompt: false
        property string prompt: ""
        property string promptForSecret: ""
        property string infoMessage: ""
        property string errorMessage: ""
        property int authenticatorTypes: 0
        signal succeeded()
        signal failed(int kind, var source)
        signal noninteractiveError(int kind, var source)
        function startAuthenticating() { console.warn("preview: started authenticating with nobody there"); }
        function stopAuthenticating() {}
        function respond(response) { console.warn("preview: sent a password with nobody there"); }
        function cancel() {}
    }

    LockScreenUnderTest {
        id: under
        anchors.fill: parent
        viewVisible: true
        greeterAuthenticator: stand
        greeterConfig: {
            const base = typeof config !== "undefined" && config ? config : ({});
            const merged = {};
            for (const k of ["alwaysShowClock", "hideClockWhenIdle", "showMediaControls",
                             "clockPosition", "wallpaperBlur", "showSessionButtons"])
                merged[k] = base[k];
            const over = JSON.parse(Qt.atob ? atob("") || "{}" : "{}");
            return Object.assign(merged, JSON.parse(previewConfig), over);
        }
    }

    Timer {
        running: true
        interval: 400
        onTriggered: {
            if (previewState === "prompt")
                under.wake();
            const sim = JSON.parse(previewConfig).simulate;
            if (sim)
                under.simulate(sim);
        }
    }

    Timer {
        running: true
        interval: previewDelay
        onTriggered: probe.grabToImage(r => {
            r.saveToFile(previewOut);
            console.warn("preview: saved");
            Qt.exit(0);
        }, Qt.size(probe.width, probe.height))
    }
}
QML

# The greeter has no way to pass values in, so they go in as QML properties
# written into the probe.
python3 - "$dir/LockScreen.qml" "$out" "$state" "$delay" "$cfg" <<'PY'
import sys, json
path, out, state, delay, cfg = sys.argv[1:6]
src = open(path).read()
src = src.replace('    readonly property var overrides: JSON.parse(Qt.application.arguments.length >= 0\n        ? (typeof PREVIEW_CONFIG !== "undefined" ? PREVIEW_CONFIG : "{}") : "{}")\n', '')
src = src.replace('previewConfig', json.dumps(json.dumps(json.loads(cfg))))
src = src.replace('const over = JSON.parse(Qt.atob ? atob("") || "{}" : "{}");\n            return Object.assign(merged, ', 'return Object.assign(merged, ')
src = src.replace(', over);', ');')
src = src.replace('previewState', json.dumps(state))
src = src.replace('previewDelay', str(int(delay)))
src = src.replace('previewOut', json.dumps(out))
open(path, 'w').write(src)
PY

mkdir -p "$(dirname "$out")"
greeter=$(lockscreen_greeter) || { echo "no greeter"; exit 1; }

# The screen the offscreen platform will invent.
cat > "$work/screen.json" <<JSON
{ "screens": [ { "name": "preview", "x": 0, "y": 0, "width": $sw, "height": $sh } ] }
JSON

LOCKSCREEN_PLATFORM="offscreen:configfile=$work/screen.json" \
lockscreen_offscreen timeout 40 "$greeter" --testing --shell "$pkg" 2>&1 \
    | grep -iE 'preview|warn|error|lacks|refus' | head -20
[ -f "$out" ] && echo "wrote $out" || echo "NO IMAGE"
