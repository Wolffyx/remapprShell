pragma Singleton

// What the network and VPN widgets show, as pure functions of what
// NetworkManager reports: the theme icon, the Material Symbols glyph for the
// same state, the hover text, and `nmcli -t` read into rows.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working; the icon names are Breeze's, for the reason given there.

import QtQuick

QtObject {
    id: root

    // Signal strength 0..1.
    function wifiIcon(strength) {
        if (!(strength > 0.05))
            return "network-wireless-signal-none";
        if (strength < 0.3)
            return "network-wireless-signal-weak";
        if (strength < 0.55)
            return "network-wireless-signal-ok";
        if (strength < 0.8)
            return "network-wireless-signal-good";
        return "network-wireless-signal-excellent";
    }

    // Whether NetworkManager's connectivity check says the connection does not
    // reach the internet. "Unknown" is what it says when the check is off, and
    // is not a problem worth a warning glyph.
    function isLimited(connectivity) {
        return connectivity === "Limited" || connectivity === "Portal" || connectivity === "None";
    }

    // s: { wired, wifi, strength, connectivity }. A wired link wins when both
    // are up, because that is the one NetworkManager routes through by default
    // and the one Plasma's applet shows.
    function networkIcon(s) {
        const limited = root.isLimited(s?.connectivity ?? "Unknown");
        if (s?.wired)
            return limited ? "network-wired-activated-limited" : "network-wired-activated";
        if (s?.wifi)
            return limited ? "network-limited" : root.wifiIcon(s.strength ?? 0);
        return "network-offline";
    }

    // Mbit/s, as NetworkManager reports it. Zero means unknown, not slow.
    function linkSpeed(mbps) {
        if (!(mbps > 0))
            return "";
        return mbps >= 1000 ? `${mbps / 1000} Gbit/s` : `${mbps} Mbit/s`;
    }

    // What hovering the network says: a line per connection -- a wired one
    // with its speed where that is known, a wireless one with its strength --
    // and a last line when NetworkManager's check says it goes nowhere.
    // `connections` is NetworkStatus's: [{ kind, name, speed, strength }].
    function networkTooltip(connections, connectivity) {
        const lines = (connections ?? []).map(c => c.kind === "wired"
            ? [c.name, root.linkSpeed(c.speed)].filter(s => s).join(" · ")
            : `${c.name} · ${StatusText.percent(c.strength)}`);
        if (lines.length === 0)
            return "Not connected";
        if (root.isLimited(connectivity))
            lines.push(connectivity === "Portal" ? "A sign-in page is in the way" : "No internet");
        return lines.join("\n");
    }

    // ---- glyphs ----------------------------------------------------------
    //
    // The same states as Material Symbols names, which is what the shell's
    // own look draws. Each follows the theme-icon rule above it, thresholds
    // and all, so the two can never say different things about one state.

    function wifiGlyph(strength) {
        if (!(strength > 0.05))
            return "signal_wifi_0_bar";
        if (strength < 0.3)
            return "network_wifi_1_bar";
        if (strength < 0.55)
            return "network_wifi_2_bar";
        if (strength < 0.8)
            return "network_wifi_3_bar";
        return "signal_wifi_4_bar";
    }

    function networkGlyph(s) {
        const limited = root.isLimited(s?.connectivity ?? "Unknown");
        if (s?.wired)
            return limited ? "signal_disconnected" : "lan";
        if (s?.wifi)
            return limited ? "signal_wifi_bad" : root.wifiGlyph(s.strength ?? 0);
        return "signal_wifi_off";
    }

    // ---- nmcli -----------------------------------------------------------

    // `nmcli -t` output as rows of fields. Fields are split on colons, and a
    // colon inside a field -- a connection named "home:5G" -- arrives as
    // "\:", which is kept as part of the field.
    function nmcliRows(text) {
        const rows = [];
        for (const line of String(text ?? "").split("\n")) {
            if (line.length === 0)
                continue;
            const fields = [];
            let cur = "";
            for (let i = 0; i < line.length; i++) {
                const c = line[i];
                if (c === "\\" && i + 1 < line.length) {
                    cur += line[++i];
                } else if (c === ":") {
                    fields.push(cur);
                    cur = "";
                } else {
                    cur += c;
                }
            }
            fields.push(cur);
            rows.push(fields);
        }
        return rows;
    }

    // The VPN and WireGuard connections, from rows of NAME:TYPE:ACTIVE.
    function vpnConnections(rows) {
        return (rows ?? [])
            .filter(r => r.length >= 3 && (r[1] === "vpn" || r[1] === "wireguard"))
            .map(r => ({ name: r[0], type: r[1], active: r[2] === "yes" }));
    }
}
