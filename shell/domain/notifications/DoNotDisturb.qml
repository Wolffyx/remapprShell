pragma Singleton

// Do not disturb, whoever draws the notifications.
//
// While this shell draws them it is the shell's own switch (ShellNotifications).
// While Plasma does -- the default -- it is Plasma's: the moment until which
// Plasma holds notifications back, `Until` in plasmanotifyrc's DoNotDisturb
// group, which is what Plasma's own applet writes when do-not-disturb is
// turned on from it. Written with kwriteconfig6 --notify, so the running
// notification server hears of it, and read back from the file, so a switch
// made in Plasma's applet shows here too.
//
// It is not ledgered. It is not configuration the shell imposes but the same
// switch the user flips in Plasma's applet, and putting an old value back on
// `revert` would be wrong.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

QtObject {
    id: root

    readonly property bool shellDraws: ShellNotifications.active

    // As KConfig writes a date: "2099,12,31,23,59,59". ISO is read too.
    property string plasmaUntil: ""
    property real _now: Date.now()

    readonly property bool plasmaActive: {
        const s = root.plasmaUntil.trim();
        if (s.length === 0)
            return false;
        const p = s.split(",").map(n => parseInt(n, 10));
        const t = p.length >= 3 && p.every(Number.isFinite)
            ? new Date(p[0], p[1] - 1, p[2], p[3] ?? 0, p[4] ?? 0, p[5] ?? 0).getTime()
            : Date.parse(s);
        return Number.isFinite(t) && t > root._now;
    }

    readonly property bool active: root.shellDraws ? ShellNotifications.dnd : root.plasmaActive

    function set(on) {
        if (root.shellDraws) {
            ShellNotifications.setDnd(on ? "on" : "off");
            return;
        }
        writer.command = on
            ? ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until", "--notify", "2099,12,31,23,59,59"]
            : ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until", "--notify", "--delete"];
        writer.running = true;
        // Shown at once; the file confirms it a moment later.
        root.plasmaUntil = on ? "2099,12,31,23,59,59" : "";
    }

    function toggle() {
        root.set(!root.active);
    }

    readonly property Process _writer: Process {
        id: writer
        onExited: code => {
            if (code !== 0)
                Log.warn("notifications", `kwriteconfig6 could not write do-not-disturb (exit ${code})`);
            view.reload();
        }
    }

    readonly property FileView _view: FileView {
        id: view
        path: `${Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")}/plasmanotifyrc`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let group = "";
            let until = "";
            for (const raw of text().split("\n")) {
                const line = raw.trim();
                if (line.startsWith("[")) {
                    group = line;
                    continue;
                }
                if (group === "[DoNotDisturb]" && line.startsWith("Until="))
                    until = line.slice(6);
            }
            root.plasmaUntil = until;
        }
        onLoadFailed: root.plasmaUntil = ""
    }

    readonly property Timer _clock: Timer {
        interval: 30000
        repeat: true
        running: root.plasmaUntil.length > 0
        onTriggered: root._now = Date.now()
    }
}
