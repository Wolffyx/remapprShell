#!/usr/bin/env bash
# Loads the Alt+Tab switcher outside KWin, to see whether it loads at all.
#
# KWin gives a layout one type, TabBoxSwitcher, from its own qrc: qmllint
# cannot resolve it, so a mistake in this file is invisible until Alt+Tab is
# pressed, where it shows up as nothing happening. `Behavior on
# anchors.topMargin` -- a load-time error, since a Behavior cannot attach to a
# member of a grouped property -- got as far as being installed that way.
#
# So: a stub of the one type KWin provides, a model of fake windows, and the
# real file on top. Errors print; "loaded" means it loaded.
#
# It checks that the file loads, not how it looks. Outside KWin there is no
# colour scheme and no Plasma dialog behind it, so a picture taken here is
# white on white and would say nothing true about the design. For the look,
# press Alt+Tab.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(cd "$HERE/../.." && pwd)

root=$(mktemp -d "$HERE/switcher.XXXX")
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/org/kde/kwin"
cat > "$root/org/kde/kwin/qmldir" <<'QMLDIR'
module org.kde.kwin
TabBoxSwitcher 1.0 TabBoxSwitcher.qml
QMLDIR

cat > "$root/org/kde/kwin/TabBoxSwitcher.qml" <<'STUB'
import QtQuick

Window {
    visible: true
    // `visible` is Item's already; redeclaring it is an error, and the error
    // is reported against the stub rather than the file under test.
    property var model: fake
    property int currentIndex: 1
    property rect screenGeometry: Qt.rect(0, 0, 2560, 1440)

    readonly property ListModel fake: ListModel {
        ListElement { caption: "shell.json — WebStorm";       icon: "code-context";       minimized: false }
        ListElement { caption: "Quickshell docs — Firefox";   icon: "firefox";            minimized: false }
        ListElement { caption: "~ : fish — Konsole";          icon: "utilities-terminal"; minimized: false }
        ListElement { caption: "Wallpapers — Dolphin";        icon: "system-file-manager"; minimized: true }
        ListElement { caption: "Remappr Shell settings";      icon: "configure";          minimized: false }
    }
    function activate(i) { }
}
STUB

cat > "$root/preview.qml" <<HARNESS
import QtQuick
import QtQuick.Window
import "."

Window {
    visible: true
    width: 1700; height: 560
    color: "#00000000"

    Loader {
        id: load
        anchors.fill: parent
        source: Qt.resolvedUrl("main.qml")
        onStatusChanged: {
            if (status === Loader.Error) { console.warn("switcher: FAILED to load"); Qt.exit(1); }
            if (status === Loader.Ready) console.warn("switcher: loaded");
        }
    }

    Timer {
        interval: 1200; running: true
        onTriggered: Qt.exit(0)
    }
}
HARNESS

cp "$WT/theme/windowswitcher/contents/ui/main.qml" "$root/main.qml"


# /usr/bin/qml is Qt5's and answers "Did not load any objects" whatever it is
# given, exactly as /usr/bin/qmllint is Qt5's. Use Qt6's.
env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
    timeout 30 /usr/lib/qt6/bin/qml -I "$root" "$root/preview.qml" 2>&1 \
  | grep -viE 'KWindowShadow|installEventFilter|platform plugin|propertyCache|support raise' \
  | grep -vE '^\s*$' | head -30
