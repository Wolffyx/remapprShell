// Tests for reading NetworkManager through nmcli's terse output.
//
// The escaping is the part that goes wrong quietly: an SSID with a colon in
// it split into two fields made a network with half its name and a signal
// of "Home". And a network seen through two access points must be one row,
// with the signal of the one actually in use.

import QtQuick
import QtTest
import qs.domain.status.network

TestCase {
    name: "NmcliState"

    function read(parts) {
        return parts.join("\n");
    }

    readonly property string sample: read([
        "@connectivity", "full",
        "@radio", "enabled:enabled",
        "@devices",
        "enp7s0:ethernet:connected:Wired connection 1",
        "wlan0:wifi:connected:Leo 5G",
        "tailscale0:tun:connected (externally):tailscale0",
        "p2p-dev-wlan0:wifi-p2p:disconnected:",
        "@wifi",
        " :Leo 5G:85:WPA2 WPA3",
        "*:Leo 5G:75:WPA2 WPA3",
        " ::74:",
        " :Cafe\\:Guest:40:",
        " :Office:60:WPA2 802.1X",
        "@saved",
        "Wired connection 1:802-3-ethernet",
        "Leo 5G:802-11-wireless",
        "@speed",
        "enp7s0:2500 Mb/s"
    ])

    function test_split_honours_escapes() {
        compare(NmcliState.split("a:b\\:c:d").join("|"), "a|b:c|d");
        compare(NmcliState.split("x\\\\y:z").join("|"), "x\\y|z");
        compare(NmcliState.split("").length, 1);
    }

    function test_the_state() {
        const s = NmcliState.parse(sample);
        compare(s.connectivity, "Full");
        compare(s.wifiEnabled, true);
        compare(s.wifiHardwareEnabled, true);
        compare(s.devices.length, 2);              // the tun and the p2p device are not ours to show
        compare(s.connections.length, 2);
        compare(s.connections[0].kind, "wired");
        compare(s.connections[0].name, "Ethernet"); // NetworkManager's own "Wired connection 1"
        compare(s.connections[0].speed, 2500);
        compare(s.connections[1].name, "Leo 5G");
        compare(s.connections[1].strength, 0.75);   // the access point in use, not the strongest
    }

    function test_networks() {
        const n = NmcliState.parse(sample).networks;
        compare(n.map(x => x.name).join("|"), "Leo 5G|Office|Cafe:Guest");  // connected, then by signal; hidden dropped
        compare(n[0].connected, true);
        compare(n[0].known, true);
        compare(n[2].secured, false);
        compare(n[1].enterprise, true);
    }

    function test_nothing_read_is_null() {
        compare(NmcliState.parse(""), null);
        compare(NmcliState.parse("error: NetworkManager is not running."), null);
    }

    function test_names_and_numbers() {
        compare(NmcliState.connectivity("portal"), "Portal");
        compare(NmcliState.connectivity("unknown"), "Unknown");
        compare(NmcliState.speed("1000 Mb/s"), 1000);
        compare(NmcliState.speed("unknown"), 0);
        compare(NmcliState.wiredName("Office LAN"), "Office LAN");
        compare(NmcliState.keyMgmt("WPA3"), "sae");
        compare(NmcliState.keyMgmt("WPA2 WPA3"), "wpa-psk");
        compare(NmcliState.keyMgmt("WPA1 WPA2"), "wpa-psk");
        compare(NmcliState.secured("OWE"), false);
    }
}
