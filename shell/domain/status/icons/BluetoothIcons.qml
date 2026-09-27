pragma Singleton

// What the Bluetooth widget shows, as pure functions of what BlueZ reports:
// the adapter's theme icon and Material Symbols glyph, and a glyph for each
// kind of device.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working; the icon names are Breeze's, for the reason given there.

import QtQuick

QtObject {
    id: root

    function bluetoothIcon(enabled, connected) {
        if (!enabled)
            return "network-bluetooth-inactive-symbolic";
        return connected > 0 ? "network-bluetooth-activated" : "network-bluetooth";
    }

    // ---- glyphs ----------------------------------------------------------
    //
    // The same states as Material Symbols names, which is what the shell's
    // own look draws. Each follows the theme-icon rule above it, so the two
    // can never say different things about one state.

    function bluetoothGlyph(enabled, connected) {
        if (!enabled)
            return "bluetooth_disabled";
        return connected > 0 ? "bluetooth_connected" : "bluetooth";
    }

    // A Bluetooth device's glyph, from the icon name BlueZ gives it
    // ("audio-headset", "input-keyboard", "phone").
    function deviceGlyph(icon) {
        const i = String(icon ?? "");
        if (/headset|headphone/.test(i))
            return "headphones";
        if (/audio|speaker/.test(i))
            return "speaker";
        if (/keyboard/.test(i))
            return "keyboard";
        if (/mouse|pointing|tablet/.test(i))
            return "mouse";
        if (/phone/.test(i))
            return "smartphone";
        if (/gaming|joystick|gamepad/.test(i))
            return "sports_esports";
        if (/computer|laptop/.test(i))
            return "computer";
        if (/watch/.test(i))
            return "watch";
        return "bluetooth";
    }
}
