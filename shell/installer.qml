// The installer's entry point: scripts/setup.sh runs
//
//   quickshell -p <source>/shell/installer.qml
//
// in a graphical session, before the shell is installed -- from the source
// tree, which is why it lives here and imports the shell's own modules
// rather than anything installed. It asks, runs setup.sh with the answers,
// and quits when closed. Not a type (lowercase): nothing imports it, and the
// running shell never loads it.

import QtQuick
import Quickshell
import qs.features.installer

ShellRoot {
    InstallerWindow {
        onDone: Qt.quit()
        onClosed: Qt.quit()
    }
}
