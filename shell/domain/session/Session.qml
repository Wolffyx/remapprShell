pragma Singleton

// Who is logged in, and for how long the machine has been up -- what the
// start menu and quick settings put at their head.
//
// The name is the one in the passwd entry, the picture the one System
// Settings saves (AccountsService's, then ~/.face.icon, then ~/.face). Read,
// never written.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string userName: Quickshell.env("USER") ?? ""
    property string realName: ""
    property string hostName: ""
    // A file path, or empty for none: the initial is drawn instead.
    property string avatar: ""
    property real uptimeSeconds: 0

    // ---- the session -------------------------------------------------------
    //
    // Locking is Plasma's screen locker, asked through logind as the lock key
    // does. Logging out, restarting and shutting down go through Plasma's own
    // prompt, which knows about unsaved work and inhibitors -- nothing here
    // ends a session without asking.

    function lock() { Quickshell.execDetached(["loginctl", "lock-session"]); }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]); }
    function hibernate() { Quickshell.execDetached(["systemctl", "hibernate"]); }

    // "promptAll", "promptLogout", "promptReboot" or "promptShutDown".
    function prompt(kind) {
        Quickshell.execDetached(["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt",
                                 "org.kde.LogoutPrompt", kind ?? "promptAll"]);
    }

    readonly property string displayName: root.realName.length > 0 ? root.realName : root.userName
    readonly property string initial: root.displayName.charAt(0).toUpperCase()

    // "up 6 h 24 min", in the words the rest of the shell uses for a time.
    readonly property string uptime: {
        const s = root.uptimeSeconds;
        if (!(s > 0))
            return "";
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        return d > 0 ? `up ${d} d ${h} h` : h > 0 ? `up ${h} h ${String(m).padStart(2, "0")} min` : `up ${m} min`;
    }

    // The name as a person reads it: the first field of the GECOS entry.
    readonly property Process _passwd: Process {
        command: ["getent", "passwd", root.userName]
        running: root.userName.length > 0
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(":");
                root.realName = (fields[4] ?? "").split(",")[0].trim();
            }
        }
    }

    // The name travels as an argument, never inside the script.
    readonly property Process _avatar: Process {
        command: ["sh", "-c", "for f in \"/var/lib/AccountsService/icons/$1\" \"$HOME/.face.icon\" \"$HOME/.face\"; do [ -r \"$f\" ] && [ -s \"$f\" ] && { printf '%s' \"$f\"; exit 0; }; done", "sh", root.userName]
        running: root.userName.length > 0
        stdout: StdioCollector {
            onStreamFinished: root.avatar = text.trim()
        }
    }

    readonly property FileView _hostname: FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostName = text().trim()
    }

    readonly property FileView _uptime: FileView {
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeSeconds = parseFloat(text().split(" ")[0]) || 0
    }

    readonly property Timer _tick: Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root._uptime.reload()
    }
}
