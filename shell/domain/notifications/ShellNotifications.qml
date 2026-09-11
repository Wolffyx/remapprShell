pragma Singleton
pragma ComponentBehavior: Bound

// This shell's own notification server: opt-in, off by default.
//
// Plasma serves notifications, and under this shell's renderer it still does,
// through the applet PlasmaServices hosts. notifications.server "shell" is a
// replacement -- the plan's Phase 8, and opt-in by its own rule -- and this is
// it: a Quickshell NotificationServer on org.freedesktop.Notifications, and
// the popups beside the panel drawn from what it holds.
//
// It never takes the name. Quickshell's server, measured on a private bus,
// registers when the name is free and otherwise waits, taking it when the
// holder lets go. So while Plasma's hosted applet or another shell's bar holds
// the name, this stands by and says who does. Whether to run at all is
// PlasmaServices' decision (Hosting.serveNotifications), made beside the
// hosting so the two can never both be on.
//
// The history and "Ask" need nothing new: the eavesdrop sees the Notify calls
// whoever answers them. Do-not-disturb holds back all but critical popups; what
// it holds back is still in the history.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core
import qs.platform.kde
import qs.domain.config
import qs.domain.backend
import qs.domain.notifications.popups

QtObject {
    id: root

    readonly property bool wanted: ConfigStore.value("notifications.server", "plasma") === "shell"
    readonly property bool serving: PlasmaServices.notifications?.serve === true
    readonly property string reason: PlasmaServices.notifications?.reason ?? ""
    readonly property int timeoutMs: Math.max(1, Number(ConfigStore.value("notifications.popupTimeout", 6))) * 1000
    readonly property string position: ConfigStore.value("notifications.popupPosition", "auto")
    readonly property bool askable: ConfigStore.value("ai.enabled", false) === true && NotificationWatch.enabled

    property bool dnd: false

    // Who holds org.freedesktop.Notifications, and whether it is this process.
    property string owner: ""
    property bool ours: false
    readonly property bool active: root.serving && root.ours

    readonly property int maxShown: 5

    readonly property var server: loader.item
    readonly property var tracked: root.server ? Array.from(root.server.trackedNotifications.values) : []
    readonly property var popups: Popups.arrange(root.tracked.map(n => ({ id: n.id, urgency: n.urgency, n: n })),
                                                 root.maxShown).map(x => x.n)

    // { id: deadline in ms since the epoch }, 0 for none. Kept here rather than
    // on each popup: the popup list is rebuilt whenever it changes, and a timer
    // on a popup would start again every time another notification arrived.
    property var deadlines: ({})
    property int held: -1

    function hold(id, on) {
        if (on) {
            root.held = id;
            return;
        }
        if (root.held === id)
            root.held = -1;
        if (root.deadlines[id] !== undefined)
            root.deadlines = Object.assign({}, root.deadlines, { [id]: Popups.released(root.deadlines[id], Date.now()) });
    }

    function _received(n) {
        if (!Popups.admits(root.dnd, n.urgency)) {
            // Left untracked, which discards it; the history still has it.
            Log.debug("notifications", `held back by do-not-disturb: ${n.appName}`);
            return;
        }
        n.tracked = true;
        const id = n.id;
        const t = Popups.timeoutFor(n.urgency, n.expireTimeout, root.timeoutMs);
        root.deadlines = Object.assign({}, root.deadlines, { [id]: t > 0 ? Date.now() + t : 0 });
        n.closed.connect(() => root._forget(id));
    }

    function _forget(id) {
        const next = Object.assign({}, root.deadlines);
        delete next[id];
        root.deadlines = next;
        if (root.held === id)
            root.held = -1;
    }

    function _find(id) {
        return root.tracked.find(x => x.id === id) ?? null;
    }

    // A click on a popup's text: its default action, or closing it.
    function activate(n) {
        const d = (n.actions ?? []).find(a => a.identifier === "default");
        if (d)
            root.invoke(n, d);
        else
            n.dismiss();
    }

    // The spec has the server close a notification once an action is taken,
    // unless the notification says it is resident. Looked up again after the
    // action, in case the application closed it itself in answer.
    function invoke(n, action) {
        const id = n.id;
        const resident = n.resident;
        action.invoke();
        if (!resident)
            Qt.callLater(() => root._find(id)?.dismiss());
    }

    function ask(n) {
        const i = Popups.historyIndex(NotificationWatch.entries,
                                      { appName: n.appName, summary: n.summary, body: n.body });
        if (i < 0) {
            Log.warn("notifications", "that notification is not in the history, so there is nothing to ask about");
            return;
        }
        Quickshell.execDetached([Branding.ctlBin, "ask", "--notification", String(i), "--review"]);
    }

    function dismissAll() {
        for (const n of root.tracked)
            n.dismiss();
    }

    function setDnd(state) {
        root.dnd = state === "toggle" ? !root.dnd : state === "on";
        return root.dnd;
    }

    function summary() {
        return {
            wanted: root.wanted,
            serving: root.serving,
            reason: root.reason,
            owner: root.owner,
            ours: root.ours,
            dnd: root.dnd,
            tracked: root.tracked.length,
            showing: root.popups.length
        };
    }

    readonly property Timer _clock: Timer {
        interval: 500
        repeat: true
        running: Object.keys(root.deadlines).length > 0
        onTriggered: {
            for (const id of Popups.due(root.deadlines, Date.now(), root.held)) {
                const n = root._find(id);
                if (n)
                    n.expire();
                else
                    root._forget(id);
            }
        }
    }

    readonly property LazyLoader _loader: LazyLoader {
        id: loader
        active: root.serving

        NotificationServer {
            actionsSupported: true
            imageSupported: true
            bodySupported: true
            bodyMarkupSupported: false
            bodyHyperlinksSupported: false
            persistenceSupported: false
            inlineReplySupported: false
            onNotification: n => root._received(n)
        }
    }

    function probeOwner() {
        ownerProc.running = false;
        ownerProc.running = true;
    }

    readonly property Process _owner: Process {
        id: ownerProc
        command: ["busctl", "--user", "status", "org.freedesktop.Notifications"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pid = (text.match(/^PID=(\d+)$/m) ?? [])[1] ?? "";
                const comm = (text.match(/^Comm=(.*)$/m) ?? [])[1] ?? "";
                root.ours = pid !== "" && Number(pid) === Quickshell.processId;
                root.owner = pid ? `${comm} (${pid})` : "";
            }
        }
    }

    onServingChanged: {
        Log.info("notifications", root.serving ? "serving notifications (notifications.server)"
                                               : `not serving notifications: ${root.reason}`);
        root.probeOwner();
    }
    onOursChanged: {
        if (root.serving && !root.ours && root.owner)
            Log.info("notifications", `standing by: ${root.owner} holds org.freedesktop.Notifications`);
    }
    Component.onCompleted: if (root.wanted) root.probeOwner()

    // The name changing hands: ours arriving, or another holder letting go.
    // Only watched when asked for, so the default costs nothing.
    readonly property DbusWatch _nameWatch: DbusWatch {
        service: "org.freedesktop.DBus"
        path: "/org/freedesktop/DBus"
        filter: "org.freedesktop.Notifications"
        running: root.wanted
        onChanged: root.probeOwner()
    }
}
