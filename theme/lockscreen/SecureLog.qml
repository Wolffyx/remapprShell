/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The secure style's log of this lock, where the design has journald: when
    it locked, each refused password, and each thing PAM said -- the newest
    first, six at most. The greeter can read no history of sign-ins, so this
    is what this greeter saw, and it ends with the lock.

    Kept apart from the rail that draws it: this is what the lock heard, and
    the rail only how it is shown. The hint under the password reads
    `faillock` from here as well.
*/
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: log

    // The frame, for the authenticator's news and when it locked.
    required property var ui
    required property SecurePalette colours

    // Set once pam_faillock has said something: only then is it known to be
    // counting this account's failures.
    property bool faillock: false
    property var seenLines: []

    // `t`, `what`, `how` and `tint`, one row to an event.
    readonly property ListModel entries: ListModel {}

    function stamp(d: date): string {
        return Qt.formatTime(d, "HH:mm:ss");
    }

    function addLog(what: string, how: string, tint: color): void {
        log.entries.insert(0, { "t": log.stamp(new Date()), "what": what, "how": how, "tint": String(tint) });
        while (log.entries.count > 6)
            log.entries.remove(log.entries.count - 1);
    }

    Component.onCompleted: {
        log.entries.append({ "t": log.stamp(log.ui.lockedAt), "what": "Locked", "how": "this greeter started", "tint": String(log.colours.mut) });
    }

    readonly property Connections authenticator: Connections {
        target: log.ui.unlock

        function onRejected() {
            log.addLog("Password refused", `attempt ${log.ui.unlock.refusals} this lock`, log.colours.bad);
        }

        // Each new line PAM says, once. "Unlocking failed" is our own word
        // for a refusal, which is logged above rather than twice.
        function onMessageChanged() {
            const lines = log.ui.unlock.message ? log.ui.unlock.message.split("\n") : [];
            for (const line of lines) {
                if (!line || log.seenLines.includes(line) || line === "Unlocking failed")
                    continue;
                const lockout = log.ui.unlock.lockoutIn(line) > 0;
                if (lockout || /faillock/i.test(line))
                    log.faillock = true;
                log.addLog(line, lockout ? "pam_faillock" : "PAM", lockout ? log.colours.bad : log.colours.mut);
            }
            log.seenLines = lines;
        }

        function onUnlockedWithoutPasswordChanged() {
            if (log.ui.unlock.unlockedWithoutPassword)
                log.addLog("Accepted without a password", "confirm to unlock", log.colours.good);
        }
    }
}
