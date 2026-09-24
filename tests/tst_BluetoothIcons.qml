// Tests for what the Bluetooth widget shows: the adapter's icon and glyph, and
// a glyph for each kind of device BlueZ names.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "BluetoothIcons"

    function test_bluetooth() {
        compare(BluetoothIcons.bluetoothIcon(false, 2), "network-bluetooth-inactive-symbolic");
        compare(BluetoothIcons.bluetoothIcon(true, 0), "network-bluetooth");
        compare(BluetoothIcons.bluetoothIcon(true, 1), "network-bluetooth-activated");
    }

    function test_bluetooth_glyph() {
        compare(BluetoothIcons.bluetoothGlyph(false, 2), "bluetooth_disabled");
        compare(BluetoothIcons.bluetoothGlyph(true, 0), "bluetooth");
        compare(BluetoothIcons.bluetoothGlyph(true, 1), "bluetooth_connected");
    }

    function test_device_glyphs() {
        compare(BluetoothIcons.deviceGlyph("audio-headset"), "headphones");
        compare(BluetoothIcons.deviceGlyph("audio-headphones"), "headphones");
        compare(BluetoothIcons.deviceGlyph("audio-card"), "speaker");
        compare(BluetoothIcons.deviceGlyph("input-keyboard"), "keyboard");
        compare(BluetoothIcons.deviceGlyph("input-mouse"), "mouse");
        compare(BluetoothIcons.deviceGlyph("phone"), "smartphone");
        compare(BluetoothIcons.deviceGlyph("input-gaming"), "sports_esports");
        compare(BluetoothIcons.deviceGlyph(""), "bluetooth");
        compare(BluetoothIcons.deviceGlyph(undefined), "bluetooth");
    }
}
