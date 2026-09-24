pragma Singleton

// A ring buffer of recent notifications, off by default.
//
// Plasma owns org.freedesktop.Notifications and a second owner cannot have it,
// so this is not a notification daemon and never will be by accident: it
// listens to the `Notify` calls other applications send Plasma, with a match
// rule narrow enough that nothing else on the bus comes through this process.
//
// It runs only while something asks for it -- the history widget, or AI assist,
// which needs a notification to have been seen before it can be asked about.
// The buffer is memory only. A notification body is exactly the sort of thing
// a person would not expect to find written to disk later, so nothing here is.
// `rmpr ask --last-notification` reaches it over IPC while the shell runs, and
// gets nothing when it does not.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.core
import qs.platform.kde
import qs.domain.config
import qs.domain.notifications.events
import qs.domain.notifications.popups
import qs.domain.windows

QtObject {
    id: root

    readonly property bool historyWanted: ConfigStore.value("notifications.history", false) === true
    readonly property bool aiWanted: ConfigStore.value("ai.enabled", false) === true
    readonly property bool enabled: root.historyWanted || root.aiWanted
    readonly property int capacity: Math.max(1, ConfigStore.value("notifications.historySize", 50))

    // Newest first. Reassigned rather than mutated so bindings see the change.
    property var entries: []
    property int unseen: 0

    signal received(var entry)

    readonly property var last: root.entries[0] ?? null

    function markSeen() { root.unseen = 0; }

    // A click on an entry in the history: the file it named, or the
    // application that sent it -- raised if it is running, started if it is
    // not. The live popups do the same thing through
    // ShellNotifications.activate; an entry in the history has no actions
    // left to invoke, so these two are all there is.
    //
    // Answers whether there was anything to open, so a row can be drawn as
    // clickable only when it is.
    function open(entry) {
        return root.go(root.targetOf(entry));
    }

    // The rule is Popups.targetFor, shared with the live popups so a click
    // means the same thing in both places.
    function targetOf(entry) {
        return Popups.targetFor({
            url: (entry?.urls ?? [])[0] ?? "",
            eventId: entry?.eventId ?? "",
            icon: entry?.appIcon ?? "",
            desktopEntry: entry?.desktopEntry ?? ""
        });
    }

    // Does what a target says, other than invoking an action, which only a
    // live notification can. Answers whether anything was done.
    function go(target) {
        switch (target?.kind) {
        case "url":
            Quickshell.execDetached(["xdg-open", target.value]);
            return true;
        case "devices":
            root.openDevices();
            return true;
        case "displays":
            PlasmaApplets.openSettings("kcm_kscreen");
            return true;
        case "app":
            WindowsService.open(target.value);
            return true;
        }
        return false;
    }

    // Disks & Devices, as a click on its tray icon opens it: the device
    // notifier this shell hosts under its own renderer. Where it is not
    // hosted -- Plasma's tray has it inside, and has no icon of its own to
    // activate -- the file manager, which lists removable devices too.
    readonly property string deviceNotifierId: "plasmawindowed_org.kde.plasma.devicenotifier"

    function openDevices() {
        const item = (SystemTray.items?.values ?? []).find(i => i?.id === root.deviceNotifierId);
        if (item) {
            item.activate();
            return;
        }
        Log.info("notifications", "no device notifier in the tray; opening the file manager instead");
        WindowsService.open("org.kde.dolphin");
    }

    // The picture an entry is about, for the centre to draw. The rule is
    // NotificationEvents', which is pure and tested.
    function pictureOf(entry) {
        return NotificationEvents.pictureOf(entry);
    }

    // Whether `open` would do anything.
    function openable(entry) {
        return root.targetOf(entry).kind !== "none";
    }
    function clear() { root.entries = []; root.unseen = 0; }

    function _push(entry) {
        const next = [entry].concat(root.entries);
        if (next.length > root.capacity)
            next.length = root.capacity;
        root.entries = next;
        root.unseen = Math.min(root.unseen + 1, root.capacity);
        root.received(entry);
        Log.debug("notifications", `${entry.appName}: ${entry.summary}`);
    }

    onCapacityChanged: {
        if (root.entries.length > root.capacity)
            root.entries = root.entries.slice(0, root.capacity);
    }

    // The eavesdrop. A match rule, not a whole-bus monitor: see BusMonitor.
    readonly property BusMonitor _monitor: BusMonitor {
        match: `type='method_call',interface='${NotificationEvents.interfaceName}',member='Notify'`
        running: root.enabled

        onRead: line => {
            const entry = NotificationEvents.parse(line);
            if (entry)
                root._push(entry);
        }

        // Said once per notification dropped, and from outside the parser:
        // the parser runs in a hot read handler and a pure function has
        // nowhere to log to anyway. A drop means a line stayed over a
        // megabyte after its pixels were removed, which should not happen --
        // so it is worth a line rather than silence.
        onDropped: n => Log.warn("notifications", `${n} notification(s) too large to read safely; skipped`)

        onListeningChanged: {
            if (listening)
                Log.info("notifications", "listening for notifications on the session bus");
            else if (root.enabled)
                Log.warn("notifications", "the notification listener stopped; the history will not grow");
        }
    }
}
