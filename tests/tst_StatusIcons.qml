// Tests for StatusIcons, the facade the status widgets are written against.
//
// The rules themselves are tested one subject to a file -- tst_AudioIcons,
// tst_NetworkIcons and the rest beside this one. What is pinned here is what
// only the facade can get wrong: a name a widget calls that no longer answers,
// or an argument handed on in the wrong place. And the OSD's glyph, the one
// rule the facade keeps, because it reads across every subject at once.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "StatusIcons"

    // ---- the OSD ----------------------------------------------------------

    function test_osd_glyphs() {
        compare(StatusIcons.osdGlyph("audio-volume-high", 0.9), "volume_up");
        compare(StatusIcons.osdGlyph("audio-volume-low", 0.1), "volume_mute");
        compare(StatusIcons.osdGlyph("audio-volume-muted", 0.6), "volume_off");
        compare(StatusIcons.osdGlyph("microphone-sensitivity-muted", 0), "mic_off");
        compare(StatusIcons.osdGlyph("video-display-brightness", 0.2), "brightness_low");
        // A lock key is not "the keyboard": both would otherwise fall to the
        // generic keyboard rule, and the glyph is the whole message here.
        compare(StatusIcons.osdGlyph("input-caps-on", 0), "keyboard_capslock");
        compare(StatusIcons.osdGlyph("input-num-on", 0), "dialpad");
        compare(StatusIcons.osdGlyph("input-keyboard", 0), "keyboard");
        compare(StatusIcons.osdGlyph("input-keyboard-brightness", 0.5), "keyboard");
        compare(StatusIcons.osdGlyph("input-touchpad-off", 0), "touchpad_mouse_off");
        compare(StatusIcons.osdGlyph("something-else", 0), "");
    }

    // ---- the facade -------------------------------------------------------

    // Every name StatusIcons had before its rules were split up, by the
    // subject that owns it now. A widget calls these by name, and a name that
    // stopped answering would fail only on the screen that draws it.
    readonly property var owners: ({
        AudioIcons: ["volumeIcon", "micIcon", "stepVolume", "volumeGlyph", "micGlyph"],
        NetworkIcons: ["wifiIcon", "isLimited", "networkIcon", "linkSpeed", "networkTooltip",
                       "wifiGlyph", "networkGlyph", "nmcliRows", "vpnConnections"],
        BluetoothIcons: ["bluetoothIcon", "bluetoothGlyph", "deviceGlyph"],
        PowerIcons: ["fraction", "batteryIcon", "profileIcon", "profileLabel", "batteryGlyph", "profileGlyph"],
        MediaPlayers: ["pickPlayer", "trackTime"],
        ClipboardHistory: ["clipboardAdd", "clipboardAddImage", "clipboardOrphans", "clipboardLabel",
                           "clipboardPreview", "klipperEntries"],
        BrightnessIcons: ["brightnessDisplays", "brightnessFloor", "stepBrightness", "brightnessFromPercent",
                          "brightnessIcon", "nightLightState", "nightLightLabel", "nightLightIcon",
                          "brightnessPanelIcon", "brightnessGlyph", "nightLightGlyph", "brightnessPanelGlyph"],
        KeyboardLayouts: ["keyboardLayouts", "layoutLabel", "cycleIndex"],
        PrivacyIcons: ["recorders", "privacyTooltip", "privacyHint", "privacyIcon", "privacyGlyph"],
        StatusText: ["percent", "duration"]
    })

    function subject(name) {
        return {
            AudioIcons: AudioIcons, NetworkIcons: NetworkIcons, BluetoothIcons: BluetoothIcons,
            PowerIcons: PowerIcons, MediaPlayers: MediaPlayers, ClipboardHistory: ClipboardHistory,
            BrightnessIcons: BrightnessIcons, KeyboardLayouts: KeyboardLayouts, PrivacyIcons: PrivacyIcons,
            StatusText: StatusText
        }[name];
    }

    // Fifty-three names forwarded, and the OSD's own: the fifty-four the
    // facade has always had.
    function test_every_name_still_answers() {
        let count = 1;
        verify(typeof StatusIcons.osdGlyph === "function", "osdGlyph");
        for (const owner of Object.keys(owners)) {
            for (const fn of owners[owner]) {
                verify(typeof StatusIcons[fn] === "function", `StatusIcons.${fn}`);
                verify(typeof subject(owner)[fn] === "function", `${owner}.${fn}`);
                count++;
            }
        }
        compare(count, 54);
    }

    // The same answer through the facade as from the subject, for the rules
    // that take the most arguments -- where a forwarder that swapped two of
    // them would still run, and say something wrong.
    function test_arguments_are_handed_on_in_order() {
        compare(StatusIcons.stepVolume(1.3, -1, 5, 1.0), AudioIcons.stepVolume(1.3, -1, 5, 1.0));
        compare(StatusIcons.stepBrightness(7, 15, -1, 5), BrightnessIcons.stepBrightness(7, 15, -1, 5));
        compare(StatusIcons.brightnessFromPercent(33, 15), BrightnessIcons.brightnessFromPercent(33, 15));
        compare(StatusIcons.brightnessPanelIcon(0.2, true, "off"), "brightness-low");
        compare(StatusIcons.brightnessPanelGlyph(0.9, false, "day"), "light_mode");
        compare(StatusIcons.cycleIndex(0, 3, -1), 2);
        compare(StatusIcons.batteryGlyph(0.55, true), "battery_charging_50");
        compare(StatusIcons.bluetoothIcon(true, 1), "network-bluetooth-activated");
        compare(StatusIcons.volumeIcon(0.8, true), "audio-volume-muted");
        compare(StatusIcons.networkTooltip([{ kind: "wifi", name: "Home", strength: 0.72 }], "Portal"),
                "Home · 72%\nA sign-in page is in the way");
        compare(StatusIcons.privacyHint({ microphone: ["Chrome"], camera: [] }, true),
                "Microphone in use by Chrome (muted)\nMiddle-click to unmute the microphone");
        compare(StatusIcons.pickPlayer([{ bus: "a", playing: false, title: "x" },
                                        { bus: "b", playing: false, title: "y" }], "b").current, 1);
        const images = StatusIcons.clipboardAddImage([], "/tmp/a.png", 800, 600, 2);
        compare(StatusIcons.clipboardLabel(images[0], 40), "Image · 800×600");
        compare(StatusIcons.clipboardPreview("abcdefghij", 5), "abcd…");
        compare(StatusIcons.duration(3600 + 5 * 60), "1 h 05 min");
        compare(StatusIcons.percent(0.456), "46%");
    }
}
