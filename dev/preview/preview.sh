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
# A copy of the whole shell, per run. Without this it stayed behind: 550 files
# of leftover roots were sitting here when the harness was first committed.
# PREVIEW_KEEP=1 leaves the rendered tree behind, for the times the picture is
# wrong and the question is what the copy actually says.
[ "${PREVIEW_KEEP:-}" = "1" ] || trap 'rm -rf "$root"' EXIT
cp -r "$WT/shell/." "$root/"
cp "$target" "$root/PreviewTarget.qml"; echo "PreviewTarget 1.0 PreviewTarget.qml" >> "$root/qmldir"; mkdir -p "$(dirname "$out")"
# What the targets share -- the stage they are drawn on, the stand-in bar --
# goes beside the target, where it finds them by name.
for f in "$HERE"/lib/*.qml; do
    cp "$f" "$root/"
    echo "$(basename "$f" .qml) 1.0 $(basename "$f")" >> "$root/qmldir"
done
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

# The configuration is read from a copy of the real one, so that whatever the
# shell writes back -- a migration it applies on reading, a setting a target
# changes -- lands in the copy and goes with it. The real one is the running
# shell's. On 2026-09-24 a preview of a branch whose schema was a version
# ahead migrated the live profile on reading it, and the running shell, a
# version behind, refused to save anything to it from then on. PREVIEW_DEMO
# puts an empty directory in the same place instead, below.
if [ "${PREVIEW_DEMO:-}" != "1" ]; then
    real_config=$(sed -n 's/.*readonly property string configDir: "\(.*\)"$/\1/p' "$root/core/Branding.qml")
    mkdir -p "$root/config"
    [ -n "$real_config" ] && [ -d "$real_config" ] && cp -r "$real_config/." "$root/config/"
    sed -i "s|readonly property string configDir: Branding.configDir|readonly property string configDir: \"$root/config\"|" "$root/core/Paths.qml"
    grep -qF "configDir: \"$root/config\"" "$root/core/Paths.qml" \
        || { echo "preview: could not point the configuration at a copy; not running on the real one" >&2; exit 1; }
fi

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

    # Before anything else: the configuration itself. A preview reads the real
    # profile, so without this the picture shows whatever this machine has
    # pinned, curated and rearranged -- which is the most personal thing on a
    # panel and the easiest to miss, because it looks like a design decision.
    # An empty directory means the shipped defaults, which is what a stranger
    # would see.
    mkdir -p "$root/demo-config"
    demo "$root/core/Paths.qml" \
        'readonly property string configDir: Branding.configDir' \
        "readonly property string configDir: \"$root/demo-config\""

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

    # The windows, which are the rest of what a screenshot gives away: what
    # somebody runs, what they called their files, what site they had open.
    #
    # Five invented ones, of four applications, with the first opened twice so
    # a grouped taskbar button has something to group. The icons are
    # freedesktop's generic names rather than any application's own, because an
    # application's icon ships with the application: name a real one and the
    # picture is a blank square on every machine that does not have it.
    #
    # `demoIcon` and `demoName` are read by the two substitutions below and by
    # nothing else, so the real lookup -- desktop entry first, window class
    # second -- is exactly as it was.
    demo "$root/domain/windows/WindowsService.qml" \
        'property var windows: []' \
        'property var windows: [
        { uuid: "f1", title: "Documents", appId: "demo-files", desktopFile: "",
          demoIcon: "system-file-manager", demoName: "Files",
          active: false, minimized: false, desktops: [], output: "PREVIEW", width: 1280, height: 800 },
        { uuid: "f2", title: "Pictures", appId: "demo-files", desktopFile: "",
          demoIcon: "system-file-manager", demoName: "Files",
          active: false, minimized: false, desktops: [], output: "PREVIEW", width: 1280, height: 800 },
        { uuid: "e1", title: "notes.md", appId: "demo-editor", desktopFile: "",
          demoIcon: "accessories-text-editor", demoName: "Text Editor",
          active: true, minimized: false, desktops: [], output: "PREVIEW", width: 1440, height: 900 },
        { uuid: "t1", title: "~", appId: "demo-terminal", desktopFile: "",
          demoIcon: "utilities-terminal", demoName: "Terminal",
          active: false, minimized: false, desktops: [], output: "PREVIEW", width: 1024, height: 700 },
        { uuid: "w1", title: "Getting started", appId: "demo-browser", desktopFile: "",
          demoIcon: "internet-web-browser", demoName: "Web Browser",
          active: false, minimized: true, desktops: [], output: "PREVIEW", width: 1600, height: 1000 }
    ]'
    demo "$root/domain/windows/WindowsService.qml" \
        'return WindowEvents.iconName(window);' \
        'return window?.demoIcon ?? WindowEvents.iconName(window);'
    demo "$root/domain/windows/WindowsService.qml" \
        'return window?.appId ?? "";' \
        'return window?.demoName ?? window?.appId ?? "";'
    # ...and the daemon must not put the real ones back a moment later.
    demo "$root/domain/windows/WindowsService.qml" \
        'root.windows = list;' \
        '// demo: the list above is fixed'

    # The start menu's "Recent" is read straight out of recently-used.xbel,
    # which is a list of the last dozen things somebody opened. An invented
    # one instead, in the same format, so the section is shown rather than
    # emptied -- a menu with a heading and nothing under it says the feature
    # does not work.
    cat > "$root/demo-recent.xbel" <<'XBEL'
<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0">
  <bookmark href="file:///home/alex/Documents/notes.md" modified="2026-09-15T09:12:00Z"><info><metadata><mime:mime-type type="text/markdown"/></metadata></info></bookmark>
  <bookmark href="file:///home/alex/Documents/layout.csv" modified="2026-09-15T08:40:00Z"><info><metadata><mime:mime-type type="text/csv"/></metadata></info></bookmark>
  <bookmark href="file:///home/alex/Pictures/coast-road.jpg" modified="2026-09-14T19:05:00Z"><info><metadata><mime:mime-type type="image/jpeg"/></metadata></info></bookmark>
  <bookmark href="file:///home/alex/Projects/shell.json" modified="2026-09-14T17:22:00Z"><info><metadata><mime:mime-type type="application/json"/></metadata></info></bookmark>
</xbel>
XBEL
    demo "$root/domain/launcher/RecentFiles.qml" \
        'path: `${Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")}/recently-used.xbel`' \
        "path: \"$root/demo-recent.xbel\""
    demo "$root/domain/launcher/RecentFiles.qml" \
        'Quickshell.env("HOME") ?? ""' '"/home/alex"'

    # The machine itself: how much memory it has, how big its disk is, how hot
    # it runs. Not identifying, but it is still an answer to "what do you
    # have", and a plausible machine says the same thing about the widget.
    demo "$root/domain/system/SystemStats.qml" \
        'property real cpu: 0
    property int cpuTemp: -1
    property real memTotal: 0
    property real memUsed: 0
    property real diskSize: 0
    property real diskFree: 0
    property real gpu: -1
    property int gpuTemp: -1
    property real netRate: 0' \
        'property real cpu: 0.21
    property int cpuTemp: 44
    property real memTotal: 16 * 1024 * 1024 * 1024
    property real memUsed: 6.1 * 1024 * 1024 * 1024
    property real diskSize: 512 * 1000 * 1000 * 1000
    property real diskFree: 214 * 1000 * 1000 * 1000
    property real gpu: 0.12
    property int gpuTemp: 39
    property real netRate: 0'
    demo "$root/domain/system/SystemStats.qml" \
        'readonly property bool running: root.watchers > 0' \
        'readonly property bool running: false'

    # What is playing is the most personal thing on a start menu, cover art and
    # all. Nothing is playing in a demo, which also spares the picture a card
    # that would be about something other than the shell.
    demo "$root/domain/status/MediaStatus.qml" \
        'readonly property var current: root.picked.current >= 0 ? root.all[root.picked.current] : null' \
        'readonly property var current: null'

    # The tray is the last thing that says whose desktop this is: it is a row
    # of the applications somebody chose to run. Four generic ones instead,
    # which also makes the chevron worth drawing.
    demo "$root/widgets/tray/Widget.qml" \
        'TrayLayout.split(SystemTray.items?.values ?? [],
                                                        root.pinned, root.hidden)' \
        '({ shown: [
        { id: "a", icon: Quickshell.iconPath("utilities-terminal", true), status: 0 },
        { id: "b", icon: Quickshell.iconPath("internet-mail", true), status: 0 },
        { id: "c", icon: Quickshell.iconPath("multimedia-volume-control", true), status: 0 },
        { id: "d", icon: Quickshell.iconPath("system-software-update", true), status: 0 }
    ], overflow: [{ id: "e", icon: Quickshell.iconPath("preferences-system-network", true), status: 0 }] })'
    # A fixed list is plain objects, and the delegates ask for the real type.
    demo "$root/widgets/tray/Widget.qml" \
        'required property SystemTrayItem modelData
                required property int index' \
        'required property var modelData
                required property int index'
    demo "$root/widgets/tray/Widget.qml" \
        'required property SystemTrayItem modelData

                        implicitWidth: 38' \
        'required property var modelData

                        implicitWidth: 38'
fi

# QT_QPA_PLATFORMTHEME=kde is what makes an icon an icon. The offscreen
# platform supplies no platform theme, so Qt has no icon theme name, so every
# `QIcon::fromTheme` misses and every application icon in the picture is a
# blank square -- which is what "the launcher preview shows empty tiles" was.
# The KDE platform theme reads kdeglobals like the real session does.
env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen \
    QT_QPA_PLATFORMTHEME=kde XDG_CURRENT_DESKTOP=KDE QT_FORCE_STDERR_LOGGING=1 \
    WT_SCRIPTS="$WT/scripts" PREVIEW_OUT="$out" PREVIEW_W="$W" PREVIEW_H="$H" PREVIEW_MODE="$MODE" PREVIEW_DELAY="$DELAY" \
    timeout 40 quickshell -n -p "$root/preview.qml" 2>&1 | grep -vE 'DEBUG|^\s*$' | grep -iE 'warn|error|fail|preview|qml:' | head -40 || true
[ -f "$out" ] && echo "wrote $out" || echo "NO IMAGE"
