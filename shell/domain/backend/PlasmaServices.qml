pragma Singleton

// Plasma services that exist only inside Plasma's system tray, kept running
// under our renderer, where there is no Plasma tray.
//
// Found on 2026-09-11, and worse than it sounds. Plasma's notification server
// is not in plasmashell: it is libnotificationmanager, loaded by the
// notifications applet's QML plugin, and plasmashell does not link it.
// Klipper is the same, loaded only by the clipboard applet. Our renderer's
// shell package draws no system tray, so under it neither exists. When an
// application then sends a notification the bus tries to activate a server:
// dbus-broker ignores Plasma's activation file as a duplicate of mako's, and
// systemd skips mako on KDE (ConditionEnvironment=!XDG_CURRENT_DESKTOP=KDE).
// The notification is dropped. The previous day's journal has the timeouts.
//
// So Plasma's own applets are hosted outside any panel, with
// `plasmawindowed --statusnotifier <applet>`: the applet stays alive, its
// service with it, and it shows as one icon in our tray -- which is where
// Plasma's notification history and do-not-disturb are then reached. Nothing
// is reimplemented. Verified on this machine with a harmless applet: one tray
// item per applet, a second applet handed to the same process, and the item
// gone the moment the process is.
//
// The rule for when (Hosting.decide) errs towards not hosting: only under our
// renderer, only when plasmashell is on our own package (so there is
// certainly no Plasma tray about to provide them), and only for a service
// whose bus name nobody owns. Each applet is started at most once per run --
// if the user quits it from its tray menu, it stays quit.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.platform.kde
import qs.domain.config
import qs.domain.backend.hosting

QtObject {
    id: root

    // The device notifier holds no bus name; without it, a USB stick being
    // plugged in goes unannounced and there is nowhere to eject it from.
    readonly property var services: [
        { applet: "org.kde.plasma.notifications", name: "org.freedesktop.Notifications", what: "notifications" },
        { applet: "org.kde.plasma.clipboard", name: "org.kde.klipper", what: "clipboard history" },
        { applet: "org.kde.plasma.devicenotifier", name: "", what: "device notifier" }
    ]

    readonly property bool enabled: ConfigStore.value("services.hostPlasma", true) === true
    readonly property string renderer: ConfigStore.value("panel.renderer", "quickshell")

    // What the last probe found, and what was decided.
    property string shellPackage: ""
    property var owned: ({})
    property var hostedIds: []
    property var decision: ({ start: [], reason: "not checked yet" })

    // Applets started by this run of the shell.
    property var started: ({})

    // Whether this shell serves notifications itself (notifications.server
    // "shell"). Decided here, beside the hosting and by the same rule, so the
    // two can never both be on: see Hosting.serveNotifications.
    readonly property string notificationServer: ConfigStore.value("notifications.server", "plasma")
    property bool notificationsReleased: false
    property var notifications: ({ serve: false, reason: "not checked yet" })

    // Before a switch to a renderer with a Plasma tray. The switch writes
    // panel.renderer only after plasmashell has changed package, by which
    // time the new tray wants the name.
    function releaseNotifications() {
        root.notificationsReleased = true;
        root._decideNotifications();
    }

    function _decideNotifications() {
        root.notifications = Hosting.serveNotifications({
            notificationServer: root.notificationServer,
            released: root.notificationsReleased,
            renderer: root.renderer,
            shellPackage: root.shellPackage,
            ourPackage: Branding.shellPackageId
        });
    }

    function reconcile() {
        probe.running = false;
        probe.running = true;
    }

    // Forgets what this run has started and looks again: for a renderer
    // switch, which is a deliberate new start, as opposed to the user
    // quitting a hosted applet, which is respected.
    function rehost() {
        root.started = ({});
        root.notificationsReleased = false;
        root.reconcile();
    }

    function summary() {
        return {
            enabled: root.enabled,
            renderer: root.renderer,
            shellPackage: root.shellPackage,
            owned: root.owned,
            inTray: root.hostedIds,
            hosting: Object.keys(root.started),
            reason: root.decision.reason,
            notificationServer: root.notificationServer,
            servingNotifications: root.notifications.serve,
            notificationsReason: root.notifications.reason
        };
    }

    function _decide(lines) {
        const owned = {};
        const hosted = [];
        let pkg = "";
        for (const line of lines) {
            const [kind, value] = line.split(" ");
            if (kind === "package")
                pkg = value ?? "";
            else if (kind === "owned" || kind === "free")
                owned[value] = kind === "owned";
            else if (kind === "hosted" && value)
                hosted.push(value);
        }
        root.shellPackage = pkg;
        root.owned = owned;
        root.hostedIds = hosted;
        root.decision = Hosting.decide({
            enabled: root.enabled,
            renderer: root.renderer,
            shellPackage: pkg,
            ourPackage: Branding.shellPackageId,
            notificationServer: root.notificationServer,
            services: root.services.map(s => ({
                applet: s.applet,
                name: s.name,
                owned: Hosting.provided(s, owned, hosted)
            }))
        });
        root._decideNotifications();
        for (const applet of root.decision.start) {
            if (root.started[applet])
                continue;
            const s = root.services.find(x => x.applet === applet);
            root.started = Object.assign({}, root.started, { [applet]: true });
            Log.info("services", `hosting Plasma's ${s.what} (${applet}): nothing else provides it under this renderer`);
            Quickshell.execDetached(["plasmawindowed", "--statusnotifier", applet]);
        }
        if (root.decision.start.length === 0)
            Log.debug("services", `not hosting: ${root.decision.reason}`);
    }

    onEnabledChanged: root.reconcile()
    onNotificationServerChanged: {
        root.handOverNotifications();
        root.reconcile();
    }

    // Asked to serve notifications itself while Plasma's hosted applet holds
    // the name, the shell would stand by for as long as that applet runs --
    // on a machine with nothing else serving them, forever. The applet is
    // ours: we started it, for exactly the job the shell is now asked to do.
    // So it is closed, as renderer.sh's stop_hosted_services closes it for a
    // renderer switch, and only when plasmawindowed really holds the name.
    // The rest -- clipboard, device notifier -- is hosted again at once.
    function handOverNotifications() {
        if (root.notificationServer !== "shell")
            return;
        handOver.running = false;
        handOver.running = true;
    }

    readonly property Process _handOver: Process {
        id: handOver
        command: ["sh", "-c",
            'pw=$(busctl --user status org.kde.plasmawindowed 2>/dev/null | sed -n "s/^PID=//p"); '
            + 'ow=$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n "s/^PID=//p"); '
            + '[ -n "$pw" ] && [ "$pw" = "$ow" ] && kill "$pw" && echo "closed $pw"']
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text.startsWith("closed"))
                    return;
                Log.info("services", `closed Plasma's hosted notifications (plasmawindowed, ${this.text.trim().split(" ")[1]}) so this shell can serve them; hosting the rest again`);
                root.rehost();
            }
        }
    }
    onRendererChanged: {
        if (root.renderer !== "quickshell")
            root.started = ({});
        root.reconcile();
    }
    Component.onCompleted: {
        // Hosted applets outlive the shell, so one from the last run may be
        // holding the name this run is asked to serve.
        root.handOverNotifications();
        root.reconcile();
    }

    readonly property Process _probe: Process {
        id: probe
        command: ["sh", "-c",
            'printf "package %s\\n" "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)"; '
            + `for n in ${root.services.filter(s => s.name).map(s => s.name).join(" ")}; do `
            + 'if busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s "$n" 2>/dev/null | grep -q true; '
            + 'then echo "owned $n"; else echo "free $n"; fi; done; '
            // The applets plasmawindowed already shows in the tray, by the Id
            // it gives their items.
            + 'busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher '
            + 'org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null '
            + '| grep -o "\\"[^\\"]*\\"" | tr -d "\\"" | while read -r it; do '
            + 'id=$(busctl --user get-property "${it%%/*}" "/${it#*/}" org.kde.StatusNotifierItem Id 2>/dev/null '
            + '| sed -e "s/^s \\"//" -e "s/\\"$//"); '
            + 'case "$id" in plasmawindowed_*) echo "hosted $id" ;; esac; done; '
            + 'echo done']
        // Only a probe that got to the end is acted on. reconcile() restarts
        // the probe, killing the one in flight, and its output still arrives:
        // a list that stopped before org.kde.klipper read Klipper's name as
        // free and would host a second Klipper beside the running one, and
        // an empty one dropped the shell's own notification server for a
        // moment -- seen on a private bus, serving flipping off and on --
        // leaving the name for anything waiting to take it.
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.length > 0);
                if (lines[lines.length - 1] !== "done")
                    return;
                root._decide(lines.slice(0, -1));
            }
        }
    }

    // Either name changing hands -- a tray loading or unloading, our own
    // hosted applet arriving, or it being quit -- is a reason to look again.
    readonly property DbusWatch _notifications: DbusWatch {
        service: "org.freedesktop.DBus"
        path: "/org/freedesktop/DBus"
        filter: "org.freedesktop.Notifications"
        onChanged: root.reconcile()
    }

    readonly property DbusWatch _klipper: DbusWatch {
        service: "org.freedesktop.DBus"
        path: "/org/freedesktop/DBus"
        filter: "org.kde.klipper"
        onChanged: root.reconcile()
    }
}
