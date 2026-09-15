#!/usr/bin/env bash
# Renders a QML item offscreen to a PNG, against a copy of the worktree's shell.
#   preview.sh <target.qml> <out.png> [width] [height] [mode] [delay-ms]
# Nothing reaches the real display: offscreen platform, no WAYLAND_DISPLAY.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(cd "$HERE/../.." && pwd)
target=$(realpath "$1"); out=$(realpath -m "$2")
W=${3:-1200}; H=${4:-800}; MODE=${5:-dark}; DELAY=${6:-2500}
root=$(mktemp -d "$HERE/root.XXXX")
rm -rf "$root"; mkdir -p "$root"
# A copy of the whole shell, per run. Without this it stayed behind: 550 files
# of leftover roots were sitting here when the harness was first committed.
trap 'rm -rf "$root"' EXIT
cp -r "$WT/shell/." "$root/"
cp "$target" "$root/PreviewTarget.qml"; echo "PreviewTarget 1.0 PreviewTarget.qml" >> "$root/qmldir"; mkdir -p "$(dirname "$out")"
cp "$HERE/harness.qml" "$root/preview.qml"
[ -d "$HERE/stubs" ] && cp "$HERE/stubs/"*.qml "$root/features/panel/"
# Attached layer-shell properties have nothing to attach to on a FloatingWindow.
sed -i -E "/WlrLayershell\.keyboardFocus:/,/WlrKeyboardFocus\.None/d; /BackgroundEffect\.blurRegion:/d" "$root/features/panel/WidgetSlot.qml"
# Full-screen layer surfaces become plain Items (PanelWindow has no offscreen
# backend); the drawing inside them is untouched.
for f in "$root"/features/overlays/*.qml "$root/features/osd/OsdOverlay.qml" "$root/features/notifications/NotificationPopups.qml" "$root"/features/desktop/*.qml "$root"/features/switchers/*.qml; do
    # The anchors block goes, written either way: the switchers put all four
    # on one line, and a range delete from there ran to the next `    }` in the
    # file -- taking most of the file with it and reporting the syntax error
    # that made at a line number that no longer meant anything.
    sed -i -E 's/^PanelWindow \{/Item {/; /^    anchors \{[^}]*\}$/d; /^    anchors \{$/,/^    \}$/d;
        /^    (margins\.|exclusionMode:|exclusiveZone:|WlrLayershell\.|BackgroundEffect\.|mask: Region|screen: |color: "transparent")/d;
        s/^    required property var modelData/    property var modelData/' "$f"
done
# Pages that shell out use Branding.ctlBin, which is the *installed* CLI from
# the main tree. Point it at this worktree's scripts instead, so a preview
# shows what this branch's commands say.
cat > "$root/ctl-preview.sh" <<'CTL'
#!/usr/bin/env bash
cmd=$1; shift
exec "$WT_SCRIPTS/$cmd.sh" "$@"
CTL
chmod +x "$root/ctl-preview.sh"
sed -i -E "s|readonly property string ctlBin: \".*\"|readonly property string ctlBin: \"$root/ctl-preview.sh\"|" "$root/core/Branding.qml"
# The schema and the defaults are read from the *installed* data directory,
# so without this a preview of the settings window shows the main tree's
# pages rather than this branch's.
sed -i "s|\${Branding.dataDir}/config/schema|$WT/config/schema|" "$root/domain/config/Schema.qml"
sed -i "s|\${Branding.dataDir}/config/defaults|$WT/config/defaults|" "$root/core/Paths.qml"
sed -i -E 's/^FloatingWindow \{/Item {/; /^    title: /d; /^    color: Theme\.s1$/d' "$root/features/settings/SettingsWindow.qml"

# PREVIEW_DEMO=1: a picture fit to publish.
#
# A shot of the real shell carries whoever took it -- the account name, the
# network they are on, the sound card they own. That is fine in a bug report
# and wrong in a README, and it also means the pictures can only ever be
# retaken on one machine. So the copied tree is given a plausible stranger
# instead, in the one place each answer is produced.
#
# Only names. Nothing here changes a layout, a size or a colour, so a demo
# shot and a real one differ in the words and in nothing else.
if [ "${PREVIEW_DEMO:-}" = "1" ]; then
    # Each substitution is checked. A silent miss would be worse than no demo
    # mode at all: the shot would look right and still carry a real name.
    demo() {
        local file=$1 from=$2 to=$3
        grep -qF "$from" "$file" || { echo "demo: no longer present in $(basename "$file"): $from" >&2; exit 1; }
        python3 - "$file" "$from" "$to" <<'PYEOF'
import sys
path, frm, to = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
open(path, "w").write(text.replace(frm, to, 1))
PYEOF
    }

    demo "$root/domain/session/Session.qml" \
        'Quickshell.env("USER") ?? ""' '"alex"'
    demo "$root/domain/session/Session.qml" \
        'property string hostName: ""' 'property string hostName: "orion"'
    # The hostname is read from a file a moment later, which puts the real one
    # back over the value above.
    demo "$root/domain/session/Session.qml" \
        'onLoaded: root.hostName = text().trim()' 'onLoaded: {}'
    demo "$root/domain/status/NetworkStatus.qml" \
        'name: joined?.name ?? ""' 'name: "Home Wi-Fi"'
    demo "$root/domain/status/AudioStatus.qml" \
        'return node?.description || node?.nickname || node?.name || "";' \
        'return node ? (node.isSink ? "Desk speakers" : "Desk microphone") : "";'
fi

WT_SCRIPTS="$WT/scripts" env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
    WT_SCRIPTS="$WT/scripts" PREVIEW_OUT="$out" PREVIEW_W="$W" PREVIEW_H="$H" PREVIEW_MODE="$MODE" PREVIEW_DELAY="$DELAY" \
    timeout 40 quickshell -n -p "$root/preview.qml" 2>&1 | grep -vE 'DEBUG|^\s*$' | grep -iE 'warn|error|fail|preview|qml:' | head -40 || true
[ -f "$out" ] && echo "wrote $out" || echo "NO IMAGE"
