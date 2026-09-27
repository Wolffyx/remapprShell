pragma Singleton

// What the network is doing, as NetworkManager sees it -- read with nmcli.
//
// It was Quickshell.Networking until 2026-09-25, when a system update
// restarted NetworkManager and the library kept the connectivity but lost
// every device, for good: the panel said "no network" on a working one until
// the shell was restarted, and a QML reload did not bring the devices back.
// nmcli is NetworkManager's own client, a read of it is as right after a
// restart as before, and the whole read takes tens of milliseconds -- so it
// is simply done again: on any signal from NetworkManager, when
// NetworkManager (re)appears, and every half minute for the signal strength,
// which changes without a signal. NmcliState turns the text into the state.
//
// Joining is here too, for the Wi-Fi page: a saved or open network with
// `nmcli device wifi connect`, and a new secured one by adding the profile
// without its password, then bringing it up with the password in a file of
// its own (0600, under $XDG_RUNTIME_DIR, gone at once) -- never on a command
// line, where every local user could read it. 802.1X is left to Plasma's
// applet, as Wi-Fi settings beyond a password always were.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.platform.kde
import qs.domain.status.icons
import qs.domain.status.network

QtObject {
    id: root

    // The last read, or null before NetworkManager has ever answered. Once
    // it has, a read that fails -- NetworkManager stopped, or restarting --
    // is a network that is down, drawn as such in the same place, not an
    // icon that vanishes and takes its neighbours along for a second.
    property var read: null
    property bool _seen: false
    property bool _again: false

    readonly property bool available: root.read !== null

    readonly property var devices: root.read?.devices ?? []
    readonly property var wiredDevices: root.devices.filter(d => d.type === "wired")
    readonly property var wifiDevices: root.devices.filter(d => d.type === "wifi")

    readonly property bool wifiEnabled: root.read?.wifiEnabled ?? false
    readonly property bool wifiHardwareEnabled: root.read?.wifiHardwareEnabled ?? false

    // "Full", "Limited", "Portal", "None" or "Unknown".
    readonly property string connectivity: root.read?.connectivity ?? "Unknown"

    // One entry per connected device: [{ kind, device, name, speed | strength }].
    readonly property var connections: root.read?.connections ?? []

    // The networks in reach, one per name: [{ key, name, signal, security,
    // secured, enterprise, connected, known }], connected first.
    readonly property var wifiNetworks: root.read?.networks ?? []

    // The network being joined, while it is.
    property string joining: ""
    // The last one that could not be joined, for the page to say so.
    property string failed: ""

    readonly property var state: {
        const wifi = root.connections.find(c => c.kind === "wifi");
        return {
            wired: root.connections.some(c => c.kind === "wired"),
            wifi: !!wifi,
            strength: wifi?.strength ?? 0,
            connectivity: root.connectivity
        };
    }

    readonly property string icon: StatusIcons.networkIcon(root.state)
    readonly property string glyph: StatusIcons.networkGlyph(root.state)

    function refresh() {
        settle.restart();
    }

    function setWifiEnabled(on) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        root.refresh();
    }

    // Asks the radio for a new list. The page does it while it is open.
    function scan() {
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        rescanRead.restart();
    }

    // `psk` only for a secured network that is not saved yet.
    function connectTo(network, psk) {
        if (!network || join.running)
            return;
        root.joining = network.name;
        root.failed = "";
        if (network.known || !network.secured || !psk) {
            join.command = ["sh", "-c", 'nmcli device wifi connect "$1" >/dev/null 2>&1; echo "::rc $?"',
                            "sh", network.name];
            join.running = true;
            return;
        }
        join.command = ["sh", "-c",
            'ssid=$1; f=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}") || exit 1; cat > "$f"; '
            + 'nmcli connection add type wifi con-name "$ssid" ssid "$ssid" wifi-sec.key-mgmt "$2" >/dev/null 2>&1 '
            + '&& nmcli connection up id "$ssid" passwd-file "$f" >/dev/null 2>&1; rc=$?; rm -f "$f"; '
            // A wrong password leaves a profile that would be shown as saved.
            + '[ $rc = 0 ] || nmcli connection delete id "$ssid" >/dev/null 2>&1; echo "::rc $rc"',
            "sh", network.name, NmcliState.keyMgmt(network.security)];
        join.stdinEnabled = true;
        join.running = true;
        join.write(`802-11-wireless-security.psk:${psk}\n`);
        join.stdinEnabled = false;
    }

    function summary() {
        return {
            available: root.available,
            connectivity: root.connectivity,
            wifiEnabled: root.wifiEnabled,
            wifiHardwareEnabled: root.wifiHardwareEnabled,
            connections: root.connections,
            icon: root.icon
        };
    }

    // ---- reading ---------------------------------------------------------------

    readonly property Process _read: Process {
        id: reader
        // Never cut short: a read killed halfway hands over half the state
        // -- connectivity without the devices -- and the panel says offline
        // for a moment. One asked for meanwhile follows it instead.
        onRunningChanged: {
            if (!running && root._again) {
                root._again = false;
                running = true;
            }
        }
        command: ["sh", "-c",
            'echo @connectivity; nmcli -t networking connectivity || exit 1; '
            + 'echo @radio; nmcli -t -f WIFI-HW,WIFI general; '
            + 'echo @devices; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device; '
            + 'echo @wifi; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no; '
            + 'echo @saved; nmcli -t -f NAME,TYPE connection show; '
            + 'echo @speed; nmcli -t -f DEVICE,TYPE device | while IFS=: read -r d t; do '
            + '[ "$t" = ethernet ] && printf "%s:%s\\n" "$d" "$(nmcli -g CAPABILITIES.SPEED device show "$d")"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const s = NmcliState.parse(text);
                if (s) {
                    root.read = s;
                    root._seen = true;
                } else if (root._seen) {
                    root.read = { connectivity: "Unknown", wifiEnabled: false, wifiHardwareEnabled: false,
                                  devices: [], networks: [], connections: [] };
                }
            }
        }
    }

    // Signals come in bursts -- a connection going up is a dozen -- so a read
    // waits for the burst to end.
    readonly property Timer _settle: Timer {
        id: settle
        interval: 250
        onTriggered: {
            if (reader.running)
                root._again = true;
            else
                reader.running = true;
        }
    }

    readonly property Timer _poll: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // A rescan answers in a few seconds, and says nothing when it does.
    readonly property Timer _rescanRead: Timer {
        id: rescanRead
        interval: 4000
        onTriggered: root.refresh()
    }

    // Everything NetworkManager says on its main object -- state, the active
    // connections, the radio, connectivity -- and it coming back after a
    // restart, which DbusWatch reports as a change too.
    readonly property DbusWatch _watch: DbusWatch {
        bus: "system"
        service: "org.freedesktop.NetworkManager"
        path: "/org/freedesktop/NetworkManager"
        onChanged: root.refresh()
    }

    readonly property Process _join: Process {
        id: join
        stdout: StdioCollector {
            onStreamFinished: {
                const rc = /::rc (\d+)/.exec(text);
                if (!rc || rc[1] !== "0") {
                    root.failed = root.joining;
                    Log.warn("network", `could not join ${root.joining}`);
                }
                root.joining = "";
                root.refresh();
            }
        }
    }

    Component.onCompleted: root.refresh()
}
