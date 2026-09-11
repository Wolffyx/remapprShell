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

    // Grouping is the one part of what KDE's task manager does that needs no
    // privilege: it is arithmetic over a list we already have. The rule that
    // matters is that order is preserved -- a taskbar whose buttons reorder
    // themselves as windows come and go is unusable.
    function test_grouping_keeps_first_appearance_order() {
        const windows = [
            windowJson({ uuid: "a", appId: "chrome" }),
            windowJson({ uuid: "b", appId: "konsole" }),
            windowJson({ uuid: "c", appId: "chrome" })
        ];
        const seen = [];
        const groups = {};
        for (const w of windows) {
            if (!groups[w.appId]) {
                groups[w.appId] = [];
                seen.push(w.appId);
            }
            groups[w.appId].push(w);
        }
        compare(seen.join(","), "chrome,konsole");
        compare(groups["chrome"].length, 2);
    }

    function test_attention_is_read() {
        const list = WindowEvents.parseList(JSON.stringify([windowJson({ demandsAttention: true }), windowJson({ uuid: "b" })]));
        compare(list[0].attention, true);
        compare(list[1].attention, false);
    }

    function attentive(uuid, props) {
        return Object.assign({ uuid: uuid, attention: true, active: false }, props ?? {});
    }

    // The moment a window began asking is kept while it keeps asking, so the
    // flash is timed from the request -- not from whenever the list last
    // changed for some other reason.
    function test_attention_keeps_its_first_moment() {
        let since = WindowEvents.attentionSince({}, [attentive("a")], 1000);
        compare(since["a"], 1000);
        since = WindowEvents.attentionSince(since, [attentive("a"), attentive("b")], 5000);
        compare(since["a"], 1000);
        compare(since["b"], 5000);
    }

    // Looked at, or no longer asking: forgotten, so asking again flashes again.
    function test_attention_ends_when_answered() {
        const since = WindowEvents.attentionSince({ a: 1000, b: 1000 },
            [attentive("a", { active: true }), attentive("b", { attention: false })], 9000);
        compare(Object.keys(since).length, 0);
        compare(WindowEvents.attentionSince(since, [attentive("a")], 12000)["a"], 12000);
    }

    function test_attention_with_nothing() {
        compare(Object.keys(WindowEvents.attentionSince(null, null, 1)).length, 0);
    }

    function test_output_is_read() {
        compare(WindowEvents.parseList(JSON.stringify([windowJson({ output: "DP-2" })]))[0].output, "DP-2");
        compare(WindowEvents.parseList(JSON.stringify([windowJson()]))[0].output, "");
    }

    function on(uuid, output, props) {
        return Object.assign({ uuid: uuid, output: output, active: false, minimized: false }, props ?? {});
    }

    // Each monitor keeps the window last used on it: focus moving to the
    // other monitor does not blank this one.
    function test_each_output_keeps_its_last_window() {
        let m = WindowEvents.lastActiveByOutput({}, [on("a", "DP-2", { active: true }), on("b", "DP-3", { stacking: 9 }),
                                                     on("c", "DP-3", { stacking: 2 })]);
        compare(m["DP-2"], "a");
        m = WindowEvents.lastActiveByOutput(m, [on("a", "DP-2", { stacking: 9 }), on("b", "DP-3"),
                                                on("c", "DP-3", { active: true })]);
        compare(m["DP-2"], "a");
        compare(m["DP-3"], "c");
    }

    // Before anything has been activated on a monitor -- the shell has just
    // started -- its panel names the window on top there.
    function test_an_unvisited_output_names_its_top_window() {
        const m = WindowEvents.lastActiveByOutput({}, [on("a", "DP-2", { active: true }),
                                                       on("b", "DP-3", { stacking: 4 }),
                                                       on("c", "DP-3", { stacking: 7 }),
                                                       on("d", "DP-3", { stacking: 9, minimized: true })]);
        compare(m["DP-3"], "c");
    }

    // Closed, minimised, or moved to the other monitor: forgotten -- and the
    // window on top of that monitor, if any, named instead.
    function test_a_window_gone_from_its_output_is_forgotten() {
        const m = WindowEvents.lastActiveByOutput({ "DP-2": "a", "DP-3": "b", "HDMI-1": "c" },
                                                  [on("a", "DP-3", { stacking: 1 }), on("b", "DP-3", { minimized: true })]);
        compare(m["DP-2"], undefined);
        compare(m["HDMI-1"], undefined);
        compare(m["DP-3"], "a");
    }

    function test_icon_prefers_the_desktop_file() {
        compare(WindowEvents.iconName(windowJson()), "org.kde.dolphin");
        // Lower-cased, which is what turns "Google-chrome" into an icon that
        // actually exists in the theme.
        compare(WindowEvents.iconName(windowJson({ desktopFile: "", appId: "Google-chrome" })), "google-chrome");
    }
}
