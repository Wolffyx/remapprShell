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

    function reconcile() {
        probe.running = false;
        probe.running = true;
    }

    // Forgets what this run has started and looks again: for a renderer
    // switch, which is a deliberate new start, as opposed to the user
    // quitting a hosted applet, which is respected.
    function rehost() {
        root.started = ({});
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
            reason: root.decision.reason
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
            services: root.services.map(s => ({
                applet: s.applet,
                name: s.name,
                owned: Hosting.provided(s, owned, hosted)
            }))
        });
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
    onRendererChanged: {
        if (root.renderer !== "quickshell")
            root.started = ({});
        root.reconcile();
    }
    Component.onCompleted: root.reconcile()

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
            + 'case "$id" in plasmawindowed_*) echo "hosted $id" ;; esac; done']
        stdout: StdioCollector {
            onStreamFinished: root._decide(this.text.split("\n").filter(l => l.length > 0))
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
