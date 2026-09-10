// Tests for the window-list parser.
//
// The payload crosses two process boundaries -- a KWin script, then a daemon --
// and arrives as JSON nested inside a DBus string. Every step is a place it can
// come back malformed, and the rule throughout is that unreadable input leaves
// the previous list alone rather than blanking the panel. That distinction is
// what these check: null for "no answer", an empty array for "no windows".

import QtQuick
import QtTest
import qs.domain.windows.events

TestCase {
    name: "WindowEvents"

    function windowJson(overrides) {
        return Object.assign({
            uuid: "1f46c057-675a-4d51-99e5-17aafdfb5b06",
            title: "Work — Dolphin",
            appId: "org.kde.dolphin",
            desktopFile: "org.kde.dolphin",
            minimized: false,
            active: false
        }, overrides ?? {});
    }

    function signalLine(payload) {
        return JSON.stringify({
            type: "signal",
            interface: "com.remappr.Shell.Windows",
            member: "Changed",
            payload: { type: "s", data: [payload] }
        });
    }

    function test_parses_a_list() {
        const list = WindowEvents.parseList(JSON.stringify([windowJson(), windowJson({ uuid: "b", active: true })]));
        compare(list.length, 2);
        compare(list[0].appId, "org.kde.dolphin");
        compare(list[1].active, true);
        compare(list[0].active, false);
    }

    function test_no_windows_is_not_no_answer() {
        // The distinction the whole service rests on.
        const empty = WindowEvents.parseList("[]");
        verify(empty !== null);
        compare(empty.length, 0);

        compare(WindowEvents.parseList("not json"), null);
        compare(WindowEvents.parseList(""), null);
        compare(WindowEvents.parseList('{"not":"a list"}'), null);
    }

    // Without one there is nothing to activate, so it is not a window we can
    // usefully show.
    function test_entries_without_a_uuid_are_dropped() {
        const list = WindowEvents.parseList(JSON.stringify([
            windowJson(), { title: "no uuid" }, null, "nonsense"
        ]));
        compare(list.length, 1);
    }

    function test_missing_fields_get_usable_defaults() {
        const list = WindowEvents.parseList(JSON.stringify([{ uuid: "x" }]));
        compare(list.length, 1);
        compare(list[0].title, "");
        compare(list[0].minimized, false);
        compare(list[0].active, false);
    }

    function test_parses_the_signal_wrapper() {
        const list = WindowEvents.parseSignal(signalLine(JSON.stringify([windowJson()])));
        compare(list.length, 1);
        compare(list[0].title, "Work — Dolphin");
    }

    function test_other_signals_are_not_window_lists() {
        compare(WindowEvents.parseSignal(JSON.stringify({
            type: "signal", interface: "com.remappr.Shell.Windows", member: "Something",
            payload: { data: ["[]"] }
        })), null);
        compare(WindowEvents.parseSignal("Monitoring bus message stream."), null);
        compare(WindowEvents.parseSignal(""), null);
    }

    // A window that has not finished starting has no title yet, and a blank
    // button is worse than one naming the application.
    function test_label_falls_back_to_the_application() {
        compare(WindowEvents.label(windowJson({ title: "" })), "org.kde.dolphin");
        compare(WindowEvents.label(windowJson()), "Work — Dolphin");
        compare(WindowEvents.label(null), "");
    }

    // Steam games have no desktop entry: the class is the numeric app id, so
    // nothing can match and the fallback is all there is.
    function test_steam_games_get_steams_icon() {
        compare(WindowEvents.iconName(windowJson({ desktopFile: "", appId: "steam_app_1407200" })), "steam");
        // But an application that merely mentions steam is not one.
        compare(WindowEvents.iconName(windowJson({ desktopFile: "", appId: "steamworks-tool" })), "steamworks-tool");
    }

    function test_icon_prefers_the_desktop_file() {
        compare(WindowEvents.iconName(windowJson()), "org.kde.dolphin");
        // Lower-cased, which is what turns "Google-chrome" into an icon that
        // actually exists in the theme.
        compare(WindowEvents.iconName(windowJson({ desktopFile: "", appId: "Google-chrome" })), "google-chrome");
    }
}
