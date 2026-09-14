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

WT_SCRIPTS="$WT/scripts" env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
    WT_SCRIPTS="$WT/scripts" PREVIEW_OUT="$out" PREVIEW_W="$W" PREVIEW_H="$H" PREVIEW_MODE="$MODE" PREVIEW_DELAY="$DELAY" \
    timeout 40 quickshell -n -p "$root/preview.qml" 2>&1 | grep -vE 'DEBUG|^\s*$' | grep -iE 'warn|error|fail|preview|qml:' | head -40 || true
[ -f "$out" ] && echo "wrote $out" || echo "NO IMAGE"
