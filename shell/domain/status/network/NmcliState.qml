pragma Singleton

// What NetworkManager says, read from one run of nmcli's terse output, as the
// state the panel draws.
//
// The shell used to read the network through Quickshell.Networking, which
// does not survive NetworkManager restarting -- a system update restarts it:
// the connectivity stayed current and every device was gone, until the whole
// shell was restarted (2026-09-25). nmcli is NetworkManager's own client,
// always installed with it, and a read of it is as good after a restart as
// before; so is the next one, which is the point.
//
// NetworkStatus runs the read (`sections` below, one `@name` line before
// each command's output) and hands the text here. In a module of its own,
// with no Quickshell import, so it can be tested without a running shell.

import QtQuick

QtObject {
    id: root

    // One terse line's fields. nmcli -t separates them with ':' and escapes
    // a ':' or '\' inside a value with '\' -- which an SSID can contain.
    function split(line) {
        const out = [];
        let cur = "";
        const s = String(line ?? "");
        for (let i = 0; i < s.length; i++) {
            const c = s[i];
            if (c === "\\" && i + 1 < s.length) {
                cur += s[++i];
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    // The text of each `@name` section, by name.
    function sections(text) {
        const out = ({});
        let name = "";
        for (const line of String(text ?? "").split("\n")) {
            const m = /^@([a-z]+)$/.exec(line);
            if (m) {
                name = m[1];
                out[name] = [];
            } else if (name && line.length > 0) {
                out[name].push(line);
            }
        }
        return out;
    }

    function connectivity(word) {
        return ({ full: "Full", limited: "Limited", portal: "Portal", none: "None" })[String(word ?? "").trim()] ?? "Unknown";
    }

    // "2500 Mb/s" -> 2500; anything else -> 0.
    function speed(text) {
        const m = /^(\d+)\s*Mb\/s/.exec(String(text ?? "").trim());
        return m ? parseInt(m[1], 10) : 0;
    }

    // NetworkManager names a wired profile it made itself "Wired connection
    // 1"; that says nothing the page does not, so it is called what it is.
    function wiredName(connection) {
        const c = String(connection ?? "");
        return c.length === 0 || /^Wired connection \d+$/.test(c) ? "Ethernet" : c;
    }

    // WPA/WPA2/WPA3 with a password, and not 802.1X, which wants more than a
    // password and is Plasma's applet's to set up.
    function secured(security) {
        const s = String(security ?? "").trim();
        return s.length > 0 && !/^OWE\b/.test(s);
    }
    function enterprise(security) {
        return /802\.1X/.test(String(security ?? ""));
    }
    // The key management a new profile is made with: SAE for a network that
    // offers WPA3 alone, WPA-PSK otherwise.
    function keyMgmt(security) {
        const s = String(security ?? "");
        const older = /WPA1|WPA2|\bWPA\b/.test(s);   // \bWPA\b: not the WPA in WPA3
        return /WPA3/.test(s) && !older ? "sae" : "wpa-psk";
    }

    // The whole state, from one read.
    function parse(text) {
        const sec = root.sections(text);
        if (!sec.connectivity)
            return null;   // nmcli did not run, or NetworkManager is not there

        const radio = root.split((sec.radio ?? [])[0] ?? "");
        const speeds = ({});
        for (const line of sec.speed ?? []) {
            const f = root.split(line);
            speeds[f[0]] = root.speed(f[1]);
        }

        const devices = (sec.devices ?? []).map(line => {
            const f = root.split(line);
            const type = f[1] === "ethernet" ? "wired" : f[1] === "wifi" ? "wifi" : f[1];
            const connection = f[3] ?? "";
            return { name: f[0], type: type, connected: f[2] === "connected", connection: connection,
                     linkSpeed: speeds[f[0]] ?? 0,
                     network: connection.length > 0
                         ? { name: type === "wired" ? root.wiredName(connection) : connection } : null };
        }).filter(d => d.type === "wired" || d.type === "wifi");

        const saved = (sec.saved ?? []).map(line => root.split(line))
            .filter(f => f[1] === "802-11-wireless").map(f => f[0]);

        // One entry per network name: a network is often seen through more
        // than one access point, and on two bands.
        const byName = ({});
        for (const line of sec.wifi ?? []) {
            const f = root.split(line);
            const name = f[1] ?? "";
            if (name.length === 0)
                continue;   // a hidden network: nothing to show or join by
            const signal = Math.max(0, Math.min(100, parseInt(f[2], 10) || 0)) / 100;
            const prev = byName[name];
            const inUse = f[0] === "*";
            if (!prev) {
                byName[name] = { key: name, name: name, signal: signal, security: f[3] ?? "",
                                 secured: root.secured(f[3]), enterprise: root.enterprise(f[3]),
                                 connected: inUse, known: saved.indexOf(name) >= 0 };
            } else if (inUse) {
                // The access point in use is the one whose signal matters.
                prev.connected = true;
                prev.signal = signal;
            } else if (!prev.connected) {
                prev.signal = Math.max(prev.signal, signal);
            }
        }
        const networks = Object.values(byName)
            .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signal - a.signal));

        const connections = [];
        for (const d of devices) {
            if (!d.connected)
                continue;
            if (d.type === "wired") {
                connections.push({ kind: "wired", device: d.name, name: root.wiredName(d.connection), speed: d.linkSpeed });
            } else {
                const joined = networks.find(n => n.connected);
                connections.push({ kind: "wifi", device: d.name, name: joined?.name ?? d.connection,
                                   strength: joined?.signal ?? 0 });
            }
        }

        return {
            connectivity: root.connectivity((sec.connectivity ?? [])[0]),
            wifiHardwareEnabled: radio[0] === "enabled",
            wifiEnabled: radio[1] === "enabled",
            devices: devices,
            networks: networks,
            connections: connections
        };
    }
}
