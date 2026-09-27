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
import "fixtures/bus.js" as Bus

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
        return Bus.signal("com.remappr.Shell.Windows", "Changed", "s", [payload]);
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

    // Which desktops a window is on. Dropped by the parser until 2026-09-14,
    // which made every window look like it was on all of them -- the overview
    // listed all eleven windows under each of two desktops.
    function test_the_desktops_a_window_is_on_survive_the_parse() {
        const list = WindowEvents.parseList(JSON.stringify([
            windowJson({ desktops: ["6e59888c", "b8d559b3"] })
        ]));
        compare(list[0].desktops.length, 2);
        compare(list[0].desktops[0], "6e59888c");
    }

    // A window's shape, which a preview letterboxes its stream with. A window
    // that did not say is 16:9 rather than a square: the guess is drawn, so it
    // has to be the likelier one.
    function test_the_windows_shape_survives_and_has_a_sane_default() {
        const sized = WindowEvents.parseList(JSON.stringify([
            windowJson({ width: 1600, height: 1200 })
        ]));
        compare(sized[0].width, 1600);
        compare(WindowEvents.aspectOf(sized[0]), 4 / 3);

        const silent = WindowEvents.parseList(JSON.stringify([windowJson()]));
        compare(silent[0].width, 0);
        compare(WindowEvents.aspectOf(silent[0]), 16 / 9);
        compare(WindowEvents.aspectOf(null), 16 / 9);
    }

    // An empty list is KWin's "on all desktops", and so is a script too old to
    // send the field. Both have to arrive as an empty array rather than
    // undefined: a filter reading undefined shows the window nowhere.
    function test_a_window_on_every_desktop_has_an_empty_list() {
        const none = WindowEvents.parseList(JSON.stringify([windowJson({ desktops: [] })]));
        compare(none[0].desktops.length, 0);

        const missing = WindowEvents.parseList(JSON.stringify([windowJson()]));
        verify(Array.isArray(missing[0].desktops));
        compare(missing[0].desktops.length, 0);

        const nonsense = WindowEvents.parseList(JSON.stringify([windowJson({ desktops: "d1" })]));
        compare(nonsense[0].desktops.length, 0);
    }

    // What a window's application is matched by beyond its app id (see
    // AppMatch), and what the daemon read about its process and the desktop
    // files named by it. From a script or a daemon too old to send them they
    // are empty rather than undefined, which only means fewer steps can match.
    function test_what_a_window_is_matched_by_survives_the_parse() {
        const w = WindowEvents.parseList(JSON.stringify([windowJson({
            resourceName: "example-inst",
            pid: 4242,
            cmdline: "/usr/bin/example-prog --x",
            processName: "example-prog",
            executables: ["/usr/bin/example-prog"],
            desktopHint: { variable: "APPDIR", path: "/m/x.desktop", name: "X", icon: "x", iconFile: "/m/x.png", extra: 1 },
            appIdFile: { name: "a file with no path names nothing" },
            iconPath: "/run/icons/0x1-abc.png"
        })]))[0];
        compare([w.resourceName, w.pid, w.cmdline, w.processName], ["example-inst", 4242, "/usr/bin/example-prog --x", "example-prog"]);
        compare(w.executables, ["/usr/bin/example-prog"]);
        compare(w.desktopHint, { variable: "APPDIR", path: "/m/x.desktop", id: "", name: "X", icon: "x", iconFile: "/m/x.png" });
        compare(w.appIdFile, null);
        compare(w.iconPath, "/run/icons/0x1-abc.png");

        const old = WindowEvents.parseList(JSON.stringify([windowJson()]))[0];
        compare([old.resourceName, old.pid, old.cmdline, old.processName, old.executables.length, old.desktopHint, old.appIdFile],
                ["", 0, "", "", 0, null, null]);

        const odd = WindowEvents.parseList(JSON.stringify([windowJson({ pid: "12", executables: "prog", desktopHint: "x" })]))[0];
        compare([odd.pid, odd.executables.length, odd.desktopHint], [0, 0, null]);
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

    // A window whose class no desktop entry names -- a game started by its
    // store's client, whose class is the client's own made-up id -- gets the
    // rule every other window gets, and no other program's icon. The class
    // names no icon in the theme, so where it is drawn it is the theme's
    // generic one.
    function test_a_class_with_no_entry_gets_the_ordinary_rule() {
        compare(WindowEvents.iconName(windowJson({ desktopFile: "", appId: "client_app_1234" })), "client_app_1234");
        compare(WindowEvents.iconName(windowJson({ desktopFile: "", appId: "Some_Game_42" })), "some_game_42");
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

    // ---- a full-screen window on a monitor ------------------------------

    function test_full_screen_is_read() {
        compare(WindowEvents.parseList(JSON.stringify([windowJson({ fullScreen: true })]))[0].fullScreen, true);
        compare(WindowEvents.parseList(JSON.stringify([windowJson()]))[0].fullScreen, false);
    }

    // The case that was reported: a game full screen, focus gone elsewhere,
    // and the panel drawn over it. What counts is that it is on top there.
    function test_the_top_window_full_screen_covers_its_monitor() {
        const ws = [on("game", "DP-2", { stacking: 9, fullScreen: true }), on("ed", "DP-2", { stacking: 3 }),
                    on("chat", "DP-3", { stacking: 12, active: true })];
        compare(WindowEvents.fullScreenOn(ws, "DP-2", "d1"), true);
        compare(WindowEvents.fullScreenOn(ws, "DP-3", "d1"), false);
    }

    // A window raised over it is what the user is looking at, so the panel
    // is wanted again.
    function test_a_window_above_it_uncovers_the_monitor() {
        const ws = [on("game", "DP-2", { stacking: 9, fullScreen: true }), on("ed", "DP-2", { stacking: 11 })];
        compare(WindowEvents.fullScreenOn(ws, "DP-2", "d1"), false);
    }

    // Minimised, or on another virtual desktop: not on screen, covers nothing
    // -- and does not hide the ordinary window below it either.
    function test_a_hidden_full_screen_window_covers_nothing() {
        compare(WindowEvents.fullScreenOn([on("game", "DP-2", { stacking: 9, fullScreen: true, minimized: true }),
                                           on("ed", "DP-2", { stacking: 3 })], "DP-2", "d1"), false);
        compare(WindowEvents.fullScreenOn([on("game", "DP-2", { stacking: 9, fullScreen: true, desktops: ["d2"] }),
                                           on("ed", "DP-2", { stacking: 3 })], "DP-2", "d1"), false);
        // On every desktop, or on this one, it does.
        compare(WindowEvents.fullScreenOn([on("game", "DP-2", { stacking: 9, fullScreen: true, desktops: [] })],
                                          "DP-2", "d1"), true);
        compare(WindowEvents.fullScreenOn([on("game", "DP-2", { stacking: 9, fullScreen: true, desktops: ["d2", "d1"] })],
                                          "DP-2", "d1"), true);
    }

    function test_no_windows_cover_nothing() {
        compare(WindowEvents.fullScreenOn([], "DP-2", "d1"), false);
        compare(WindowEvents.fullScreenOn(undefined, "DP-2", "d1"), false);
    }

    // ---- a window reaching a floating panel's edge ------------------------

    // DP-2 as KWin reported it: below DP-3's top, 2560x1440. The panel is at
    // the bottom and reserves 66 px.
    readonly property var dp2: ({ x: 0, y: 1040, width: 2560, height: 1440 })

    function at(uuid, x, y, w, h, props) {
        return Object.assign({ uuid: uuid, output: "DP-2", minimized: false, x: x, y: y, width: w, height: h },
                             props ?? {});
    }

    function test_position_is_read() {
        const w = WindowEvents.parseList(JSON.stringify([windowJson({ x: 720, y: 1360 })]))[0];
        compare(w.x, 720);
        compare(w.y, 1360);
        compare(WindowEvents.parseList(JSON.stringify([windowJson()]))[0].x, 0);
    }

    // Maximised, it stops where the reserved space starts: touching the
    // panel, which is what fills the edge.
    function test_a_maximised_window_reaches_the_edge() {
        compare(WindowEvents.reachesEdge([at("max", 0, 1040, 2560, 1374)], "d1", dp2, "bottom", 66), true);
    }

    function test_a_window_clear_of_the_panel_does_not() {
        compare(WindowEvents.reachesEdge([at("mid", 720, 1360, 1120, 748)], "d1", dp2, "bottom", 66), false);
        // One pixel short of touching.
        compare(WindowEvents.reachesEdge([at("near", 0, 1040, 2560, 1373)], "d1", dp2, "bottom", 66), false);
    }

    // Minimised, on another desktop, or on the other monitor: not there.
    function test_only_windows_on_this_screen_and_desktop_count() {
        compare(WindowEvents.reachesEdge([at("min", 0, 1040, 2560, 1440, { minimized: true })], "d1", dp2, "bottom", 66), false);
        compare(WindowEvents.reachesEdge([at("away", 0, 1040, 2560, 1440, { desktops: ["d2"] })], "d1", dp2, "bottom", 66), false);
        compare(WindowEvents.reachesEdge([at("dp3", 2560, 0, 1440, 2560)], "d1", dp2, "bottom", 66), false);
        compare(WindowEvents.reachesEdge([at("all", 0, 1040, 2560, 1440, { desktops: [] })], "d1", dp2, "bottom", 66), true);
    }

    function test_each_edge() {
        compare(WindowEvents.reachesEdge([at("t", 100, 1040, 400, 300)], "d1", dp2, "top", 66), true);
        compare(WindowEvents.reachesEdge([at("t", 100, 1200, 400, 300)], "d1", dp2, "top", 66), false);
        compare(WindowEvents.reachesEdge([at("l", 0, 1200, 400, 300)], "d1", dp2, "left", 66), true);
        compare(WindowEvents.reachesEdge([at("r", 2200, 1200, 360, 300)], "d1", dp2, "right", 66), true);
        compare(WindowEvents.reachesEdge([at("r", 2000, 1200, 300, 300)], "d1", dp2, "right", 66), false);
    }

    // A window from a script too old to send its geometry has none, and
    // reaches nothing.
    function test_no_geometry_reaches_nothing() {
        compare(WindowEvents.reachesEdge([at("old", 0, 0, 0, 0)], "d1", dp2, "bottom", 66), false);
        compare(WindowEvents.reachesEdge([], "d1", dp2, "bottom", 66), false);
        compare(WindowEvents.reachesEdge([at("max", 0, 1040, 2560, 1374)], "d1", null, "bottom", 66), false);
    }

    function group(key, count) {
        const windows = [];
        for (let i = 0; i < (count ?? 1); ++i)
            windows.push({ uuid: `${key}-${i}` });
        return { key: key, windows: windows };
    }

    function launcher(id) {
        return id === "gone" ? null : { key: id, appKey: id, windows: [] };
    }

    function keys(items) {
        return items.map(i => `${i.key}${i.pinned ? "*" : ""}${i.launcher ? "^" : ""}`).join(",");
    }

    // Pinned first, in pin order, whether running or not; then the rest in
    // the order they appeared. A pinned application that is running holds its
    // windows in its pinned place.
    function test_pinned_first_then_the_rest() {
        const items = WindowEvents.arrangeTasks(
            [group("konsole"), group("org.kde.dolphin"), group("class:client_app_1")],
            ["org.kde.dolphin", "google-chrome"], launcher);
        compare(keys(items), "org.kde.dolphin*,google-chrome*^,konsole,class:client_app_1");
        compare(items[1].windows.length, 0);
    }

    // An application uninstalled since it was pinned is skipped, and a pin
    // listed twice counts once.
    function test_missing_and_repeated_pins() {
        const items = WindowEvents.arrangeTasks([group("konsole")], ["gone", "konsole", "konsole"], launcher);
        compare(keys(items), "konsole*");
    }

    // Ungrouped, each window is its own item; all of a pinned application's
    // windows go to its place.
    function test_ungrouped_windows_follow_their_pin() {
        const items = WindowEvents.arrangeTasks([
            { key: "w1", appKey: "konsole", windows: [{}] },
            { key: "w2", appKey: "org.kde.dolphin", windows: [{}] },
            { key: "w3", appKey: "konsole", windows: [{}] }
        ], ["konsole"], launcher);
        compare(keys(items), "w1*,w3*,w2");
    }

    function test_app_id_of_an_item() {
        compare(WindowEvents.appIdOf({ key: "org.kde.dolphin" }), "org.kde.dolphin");
        compare(WindowEvents.appIdOf({ key: "class:client_app_1" }), "");
        compare(WindowEvents.appIdOf({ key: "uuid", appKey: "konsole" }), "konsole");
        compare(WindowEvents.appIdOf(null), "");
    }

    function test_toggle_pinned() {
        compare(WindowEvents.togglePinned(["a"], "b"), ["a", "b"]);
        compare(WindowEvents.togglePinned(["a", "b"], "a"), ["b"]);
        compare(WindowEvents.togglePinned(null, "a"), ["a"]);
        compare(WindowEvents.togglePinned(["a"], ""), ["a"]);
    }

    // The hash both switchers drew with before it was shared: the same id
    // always gets the same hue, a hue is a fraction of the wheel, and a
    // window with no id at all is not an error.
    function test_a_tint_per_application() {
        compare(WindowEvents.tintHue("org.kde.dolphin"), WindowEvents.tintHue("org.kde.dolphin"));
        verify(WindowEvents.tintHue("org.kde.dolphin") !== WindowEvents.tintHue("firefox"));
        compare(WindowEvents.tintHue(""), 0);
        compare(WindowEvents.tintHue(undefined), 0);
        // "a" is 97: 97 degrees of 360.
        compare(WindowEvents.tintHue("a"), 97 / 360);
        // (97 * 31 + 98) % 360 = 225.
        compare(WindowEvents.tintHue("ab"), 225 / 360);
        for (const id of ["", "x", "org.kde.konsole", "client_app_5678", "a".repeat(500)]) {
            const hue = WindowEvents.tintHue(id);
            verify(hue >= 0 && hue < 1, `${id}: ${hue}`);
        }
    }

    function test_icon_prefers_the_desktop_file() {
        compare(WindowEvents.iconName(windowJson()), "org.kde.dolphin");
        // Lower-cased, which is what turns "Example-Viewer" into an icon that
        // actually exists in the theme.
        compare(WindowEvents.iconName(windowJson({ desktopFile: "", appId: "Example-Viewer" })), "example-viewer");
    }
}
