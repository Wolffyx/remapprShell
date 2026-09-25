// Tests for what the network and VPN widgets show.
//
// Which link wins, when a warning is a warning, what hovering says, and how
// `nmcli -t` is read: each is a rule a person trusts without checking, and
// none of them can be seen on a machine whose network is always fine.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "NetworkIcons"

    function test_wifi_strength() {
        compare(NetworkIcons.wifiIcon(0), "network-wireless-signal-none");
        compare(NetworkIcons.wifiIcon(0.2), "network-wireless-signal-weak");
        compare(NetworkIcons.wifiIcon(0.5), "network-wireless-signal-ok");
        compare(NetworkIcons.wifiIcon(0.7), "network-wireless-signal-good");
        compare(NetworkIcons.wifiIcon(0.95), "network-wireless-signal-excellent");
    }

    // With both up, the wired link is the one traffic goes through.
    function test_wired_wins_over_wifi() {
        compare(NetworkIcons.networkIcon({ wired: true, wifi: true, strength: 0.9, connectivity: "Full" }),
                "network-wired-activated");
    }

    function test_limited_connectivity_is_shown() {
        compare(NetworkIcons.networkIcon({ wired: true, connectivity: "Portal" }),
                "network-wired-activated-limited");
        compare(NetworkIcons.networkIcon({ wifi: true, strength: 0.9, connectivity: "Limited" }),
                "network-limited");
    }

    // "Unknown" is what the check reports when it is switched off. That is not
    // a warning, or everyone who disabled the check would see one forever.
    function test_unknown_connectivity_is_not_a_warning() {
        compare(NetworkIcons.networkIcon({ wifi: true, strength: 0.9, connectivity: "Unknown" }),
                "network-wireless-signal-excellent");
    }

    function test_nothing_connected() {
        compare(NetworkIcons.networkIcon({}), "network-offline");
        compare(NetworkIcons.networkIcon(null), "network-offline");
    }

    function test_link_speed() {
        compare(NetworkIcons.linkSpeed(0), "");
        compare(NetworkIcons.linkSpeed(100), "100 Mbit/s");
        compare(NetworkIcons.linkSpeed(1000), "1 Gbit/s");
        compare(NetworkIcons.linkSpeed(2500), "2.5 Gbit/s");
    }

    // What the network widget and the status cluster both say on hover.
    function test_network_tooltip() {
        const wired = { kind: "wired", name: "Wired connection 1", speed: 1000 };
        const wifi = { kind: "wifi", name: "Home", strength: 0.72 };
        compare(NetworkIcons.networkTooltip([wired, wifi], "Full"),
                "Wired connection 1 · 1 Gbit/s\nHome · 72%");
        // A speed nobody reported is left out, not shown as nothing.
        compare(NetworkIcons.networkTooltip([{ kind: "wired", name: "eth0", speed: 0 }], "Full"), "eth0");
        compare(NetworkIcons.networkTooltip([wifi], "Portal"), "Home · 72%\nA sign-in page is in the way");
        compare(NetworkIcons.networkTooltip([wifi], "Limited"), "Home · 72%\nNo internet");
        // Nothing connected says so, whatever the check thinks.
        compare(NetworkIcons.networkTooltip([], "None"), "Not connected");
        compare(NetworkIcons.networkTooltip(undefined, "Unknown"), "Not connected");
    }

    // ---- glyphs: the same states in Material Symbols -----------------------

    function test_wifi_glyph_steps() {
        compare(NetworkIcons.wifiGlyph(0), "signal_wifi_0_bar");
        compare(NetworkIcons.wifiGlyph(0.2), "network_wifi_1_bar");
        compare(NetworkIcons.wifiGlyph(0.4), "network_wifi_2_bar");
        compare(NetworkIcons.wifiGlyph(0.7), "network_wifi_3_bar");
        compare(NetworkIcons.wifiGlyph(0.9), "signal_wifi_4_bar");
    }

    function test_network_glyph_wired_wins_and_limited_shows() {
        compare(NetworkIcons.networkGlyph({ wired: true, wifi: true, strength: 0.9 }), "lan");
        compare(NetworkIcons.networkGlyph({ wired: true, connectivity: "Limited" }), "signal_disconnected");
        compare(NetworkIcons.networkGlyph({ wifi: true, strength: 0.9, connectivity: "Portal" }), "signal_wifi_bad");
        compare(NetworkIcons.networkGlyph({ wifi: true, strength: 0.9, connectivity: "Unknown" }), "signal_wifi_4_bar");
        compare(NetworkIcons.networkGlyph({}), "signal_wifi_off");
    }

    // ---- nmcli -------------------------------------------------------------

    // A colon in a connection's name arrives escaped, and stays in the name.
    function test_nmcli_rows_keep_escaped_colons() {
        const rows = NetworkIcons.nmcliRows("home\\:5G:802-11-wireless:yes\nwork vpn:vpn:no\n");
        compare(rows.length, 2);
        compare(rows[0], ["home:5G", "802-11-wireless", "yes"]);
        compare(rows[1], ["work vpn", "vpn", "no"]);
        compare(NetworkIcons.nmcliRows("").length, 0);
    }

    function test_vpn_connections_are_vpn_and_wireguard_only() {
        const rows = NetworkIcons.nmcliRows("wired:802-3-ethernet:yes\noffice:vpn:no\nwg0:wireguard:yes\n");
        const vpns = NetworkIcons.vpnConnections(rows);
        compare(vpns.length, 2);
        compare(vpns[0].name, "office");
        compare(vpns[0].active, false);
        compare(vpns[1].type, "wireguard");
        compare(vpns[1].active, true);
    }
}
