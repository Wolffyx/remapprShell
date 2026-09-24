pragma Singleton

// What the status widgets show, as pure functions of the state they read.
//
// Kept apart from the singletons that read PipeWire, NetworkManager, BlueZ and
// UPower, in a module of its own, so qmltestrunner can load it: a module with
// one Quickshell import in it cannot be imported by the tests at all, and
// every pure function beside it becomes untestable by association.
//
// The icon names are Breeze's, and they are the ones Plasma's own applets ask
// for -- so a panel drawn by us and one drawn by Plasma show the same glyph
// for the same state, and an icon theme that styles one styles both.
//
// The rules themselves live one subject to a singleton, beside this file and
// each with a test file of its own. This is the facade the widgets were
// written against, and it stays: every name it has ever had forwards to the
// subject that owns it, so splitting the rules up changed no caller, and a
// caller never has to know which subject a rule belongs to. The one rule kept
// here is the OSD's glyph, which reads across every subject.

import QtQuick

QtObject {
    id: root

    // ---- audio: AudioIcons -------------------------------------------------

    function volumeIcon(volume, muted) { return AudioIcons.volumeIcon(volume, muted); }
    function micIcon(volume, muted) { return AudioIcons.micIcon(volume, muted); }
    function stepVolume(volume, steps, step, max) { return AudioIcons.stepVolume(volume, steps, step, max); }
    function volumeGlyph(volume, muted) { return AudioIcons.volumeGlyph(volume, muted); }
    function micGlyph(volume, muted) { return AudioIcons.micGlyph(volume, muted); }

    // ---- network: NetworkIcons ---------------------------------------------

    function wifiIcon(strength) { return NetworkIcons.wifiIcon(strength); }
    function isLimited(connectivity) { return NetworkIcons.isLimited(connectivity); }
    function networkIcon(s) { return NetworkIcons.networkIcon(s); }
    function linkSpeed(mbps) { return NetworkIcons.linkSpeed(mbps); }
    function networkTooltip(connections, connectivity) { return NetworkIcons.networkTooltip(connections, connectivity); }
    function wifiGlyph(strength) { return NetworkIcons.wifiGlyph(strength); }
    function networkGlyph(s) { return NetworkIcons.networkGlyph(s); }
    function nmcliRows(text) { return NetworkIcons.nmcliRows(text); }
    function vpnConnections(rows) { return NetworkIcons.vpnConnections(rows); }

    // ---- bluetooth: BluetoothIcons -----------------------------------------

    function bluetoothIcon(enabled, connected) { return BluetoothIcons.bluetoothIcon(enabled, connected); }
    function bluetoothGlyph(enabled, connected) { return BluetoothIcons.bluetoothGlyph(enabled, connected); }
    function deviceGlyph(icon) { return BluetoothIcons.deviceGlyph(icon); }

    // ---- power: PowerIcons -------------------------------------------------

    function fraction(p) { return PowerIcons.fraction(p); }
    function batteryIcon(fraction, charging) { return PowerIcons.batteryIcon(fraction, charging); }
    function profileIcon(profile) { return PowerIcons.profileIcon(profile); }
    function profileLabel(profile) { return PowerIcons.profileLabel(profile); }
    function batteryGlyph(fraction, charging) { return PowerIcons.batteryGlyph(fraction, charging); }
    function profileGlyph(profile) { return PowerIcons.profileGlyph(profile); }

    // ---- media: MediaPlayers -----------------------------------------------

    function pickPlayer(players, chosen) { return MediaPlayers.pickPlayer(players, chosen); }
    function trackTime(seconds) { return MediaPlayers.trackTime(seconds); }

    // ---- clipboard: ClipboardHistory ---------------------------------------

    function clipboardAdd(list, text, limit) { return ClipboardHistory.clipboardAdd(list, text, limit); }
    function clipboardAddImage(list, path, width, height, limit) {
        return ClipboardHistory.clipboardAddImage(list, path, width, height, limit);
    }
    function clipboardOrphans(before, after) { return ClipboardHistory.clipboardOrphans(before, after); }
    function clipboardLabel(entry, max) { return ClipboardHistory.clipboardLabel(entry, max); }
    function clipboardPreview(text, max) { return ClipboardHistory.clipboardPreview(text, max); }
    function klipperEntries(items) { return ClipboardHistory.klipperEntries(items); }

    // ---- brightness and Night Light: BrightnessIcons -----------------------

    function brightnessDisplays(lines) { return BrightnessIcons.brightnessDisplays(lines); }
    function brightnessFloor(max) { return BrightnessIcons.brightnessFloor(max); }
    function stepBrightness(value, max, steps, step) { return BrightnessIcons.stepBrightness(value, max, steps, step); }
    function brightnessFromPercent(percent, max) { return BrightnessIcons.brightnessFromPercent(percent, max); }
    function brightnessIcon(fraction) { return BrightnessIcons.brightnessIcon(fraction); }
    function nightLightState(nl) { return BrightnessIcons.nightLightState(nl); }
    function nightLightLabel(nl) { return BrightnessIcons.nightLightLabel(nl); }
    function nightLightIcon(state) { return BrightnessIcons.nightLightIcon(state); }
    function brightnessPanelIcon(fraction, hasDisplays, nightState) {
        return BrightnessIcons.brightnessPanelIcon(fraction, hasDisplays, nightState);
    }
    function brightnessGlyph(fraction) { return BrightnessIcons.brightnessGlyph(fraction); }
    function nightLightGlyph(state) { return BrightnessIcons.nightLightGlyph(state); }
    function brightnessPanelGlyph(fraction, hasDisplays, nightState) {
        return BrightnessIcons.brightnessPanelGlyph(fraction, hasDisplays, nightState);
    }

    // ---- keyboard: KeyboardLayouts -----------------------------------------

    function keyboardLayouts(rows) { return KeyboardLayouts.keyboardLayouts(rows); }
    function layoutLabel(layout) { return KeyboardLayouts.layoutLabel(layout); }
    function cycleIndex(index, count, steps) { return KeyboardLayouts.cycleIndex(index, count, steps); }

    // ---- privacy: PrivacyIcons ---------------------------------------------

    function recorders(links) { return PrivacyIcons.recorders(links); }
    function privacyTooltip(users, micMuted) { return PrivacyIcons.privacyTooltip(users, micMuted); }
    function privacyHint(users, micMuted) { return PrivacyIcons.privacyHint(users, micMuted); }
    function privacyIcon(users, micMuted) { return PrivacyIcons.privacyIcon(users, micMuted); }
    function privacyGlyph(users, micMuted) { return PrivacyIcons.privacyGlyph(users, micMuted); }

    // ---- text: StatusText --------------------------------------------------

    function percent(v) { return StatusText.percent(v); }
    function duration(seconds) { return StatusText.duration(seconds); }

    // ---- the OSD -----------------------------------------------------------

    // The glyph for what Plasma's OSD says changed, from the icon name it
    // sends with it and, for a level, how far along it is (0..1). Kept here
    // rather than in a subject of its own, because it is every subject at
    // once: a level reuses the volume's and the brightness's own glyph rules,
    // and the rest name a glyph for what Plasma says it is.
    function osdGlyph(icon, fraction) {
        const i = String(icon ?? "");
        if (i.startsWith("audio-volume"))
            return i.endsWith("muted") ? "volume_off" : AudioIcons.volumeGlyph(fraction, false);
        if (i.startsWith("microphone"))
            return i.endsWith("muted") ? "mic_off" : "mic";
        if (/keyboard-brightness|kbd-backlight/.test(i))
            return "keyboard";
        if (/brightness/.test(i))
            return BrightnessIcons.brightnessGlyph(fraction);
        // Before the general keyboard rule below, which would otherwise take
        // both of these: a lock key is not "the keyboard", and the glyph is
        // the whole message when there is no bar to read.
        if (/caps/.test(i))
            return "keyboard_capslock";
        if (/num-?(lock|on|off)/.test(i))
            return "dialpad";
        if (/touchpad/.test(i))
            return /off|disabled/.test(i) ? "touchpad_mouse_off" : "touchpad_mouse";
        if (/keyboard|input-kb/.test(i))
            return "keyboard";
        if (/airplane|flight/.test(i))
            return "flight";
        if (/bluetooth/.test(i))
            return "bluetooth";
        if (/wireless|wifi|network/.test(i))
            return "wifi";
        if (/battery/.test(i))
            return "battery_full";
        return "";
    }
}
