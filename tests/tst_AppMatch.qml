// Tests for finding a window's application the way Plasma's task manager
// does (libtaskmanager's serviceFromMetadata, servicesFromEnvironment and
// servicesFromCmdLine, and appDataFromService for the icon).
//
// Each step is checked on its own, and then against the one after it: the
// order is the whole point, since a window can fit several steps and the
// first one decides. The entries are made up, as are the windows -- which go
// through WindowEvents.parseList first, so what is matched is what the shell
// would have been handed.

import QtQuick
import QtTest
import qs.domain.windows.events

TestCase {
    name: "AppMatch"

    function entry(id, over) {
        return Object.assign({
            id: id, name: id, noDisplay: false, startupClass: "", execString: "", icon: ""
        }, over ?? {});
    }

    // The installed entries: the ones a menu shows go into the index, as
    // DesktopEntries.applications has them; byId sees every one, hidden or
    // not, as DesktopEntries.byId does.
    function catalogue(entries) {
        return {
            index: AppMatch.index(entries.filter(e => !e.noDisplay)),
            byId: id => entries.find(e => e.id.toLowerCase() === String(id).toLowerCase()) ?? null
        };
    }

    function window(over) {
        return WindowEvents.parseList(JSON.stringify([Object.assign({
            uuid: "1f46c057-675a-4d51-99e5-17aafdfb5b06",
            title: "A document",
            appId: "",
            desktopFile: ""
        }, over ?? {})]))[0];
    }

    function match(entries, over) {
        const c = catalogue(entries);
        return AppMatch.match(window(over), c.index, c.byId);
    }

    // Which entry, and by which step -- or "none".
    function found(entries, over) {
        const app = match(entries, over);
        if (!app)
            return "none";
        return `${app.entry ? app.entry.id : app.key}@${app.step}`;
    }

    // Plasma's app id: the desktop file KWin named, else the class.
    function test_the_app_id_is_the_desktop_file_else_the_class() {
        compare(AppMatch.appIdOf(window({ desktopFile: "org.example.Viewer", appId: "viewer" })), "org.example.Viewer");
        compare(AppMatch.appIdOf(window({ appId: "viewer" })), "viewer");
        compare(AppMatch.appIdOf(null), "");
    }

    // ---- each step on its own -------------------------------------------

    // 1. StartupWMClass, without regard to case, against the instance name
    // and against the app id.
    function test_startup_class_against_the_instance_and_the_app_id() {
        const entries = [entry("org.example.Viewer", { startupClass: "Example-Viewer" })];
        compare(found(entries, { appId: "unrelated", resourceName: "example-viewer" }), "org.example.Viewer@startupClass");
        compare(found(entries, { appId: "EXAMPLE-VIEWER" }), "org.example.Viewer@startupClass");
    }

    // The instance name is asked first.
    function test_the_instance_name_before_the_app_id() {
        const entries = [
            entry("org.example.ByClass", { startupClass: "example-class" }),
            entry("org.example.ByInstance", { startupClass: "example-instance" })
        ];
        compare(found(entries, { appId: "example-class", resourceName: "example-instance" }),
                "org.example.ByInstance@startupClass");
    }

    // Several entries claiming one class: the one whose id begins with it,
    // else the first by id.
    function test_among_several_the_one_named_for_it() {
        const entries = [
            entry("a-submenu-example-tool", { startupClass: "example-tool" }),
            entry("example-tool", { startupClass: "example-tool" }),
            entry("z-other", { startupClass: "example-tool" })
        ];
        compare(found(entries, { appId: "example-tool" }), "example-tool@startupClass");
        const unnamed = [
            entry("z-second", { startupClass: "example-tool" }),
            entry("b-first", { startupClass: "example-tool" })
        ];
        compare(found(unnamed, { appId: "example-tool" }), "b-first@startupClass");
    }

    // 2. An app id that is a desktop file's path: the file the daemon read.
    function test_an_app_id_that_is_a_path() {
        const app = match([], {
            desktopFile: "/opt/example/example.desktop",
            appIdFile: { path: "/opt/example/example.desktop", name: "Example", icon: "example", iconFile: "/opt/example/example.png" }
        });
        compare(app.step, "path");
        compare(app.entry, null);
        compare(app.name, "Example");
        compare(app.iconFile, "/opt/example/example.png");
        compare(app.key, "file:/opt/example/example.desktop");
        // Only a path: a file the daemon read for any other app id is not asked.
        compare(found([], { appId: "example", appIdFile: { path: "/x.desktop", name: "X" } }), "none");
    }

    // 3. The entry the app id names -- without regard to case, and hidden
    // from menus or not.
    function test_the_entry_the_app_id_names() {
        const entries = [entry("org.example.Viewer"), entry("org.example.Hidden", { noDisplay: true })];
        compare(found(entries, { desktopFile: "org.example.viewer" }), "org.example.Viewer@id");
        compare(found(entries, { appId: "org.example.Hidden" }), "org.example.Hidden@id");
    }

    // 4. The app id as a Name, among the entries a menu shows.
    function test_the_app_id_as_a_name() {
        const entries = [
            entry("org.example.Viewer", { name: "Example Viewer" }),
            entry("org.example.Hidden", { name: "Hidden Thing", noDisplay: true })
        ];
        compare(found(entries, { appId: "example viewer" }), "org.example.Viewer@name");
        compare(found(entries, { appId: "hidden thing" }), "none");
        // Handed a hidden entry anyway, the index still leaves its Name out.
        compare(AppMatch.match(window({ appId: "hidden thing" }), AppMatch.index(entries), null), null);
    }

    // 5. The environment: a desktop file hint counts as the installed entry
    // at that path; a mounted application's desktop file as it is.
    function test_the_desktop_file_the_environment_names() {
        const entries = [entry("sub-org.example.Packaged", { name: "Packaged" })];
        compare(found(entries, { appId: "packaged-bin",
                                 desktopHint: { variable: "BAMF_DESKTOP_FILE_HINT", path: "/apps/sub/org.example.Packaged.desktop",
                                                id: "sub-org.example.Packaged" } }),
                "sub-org.example.Packaged@environment");

        const mounted = match([], { appId: "mounted-bin",
                                    desktopHint: { variable: "APPDIR", path: "/tmp/.mount_x/example.desktop",
                                                   name: "Mounted Example", icon: "example", iconFile: "/tmp/.mount_x/example.png" } });
        compare(mounted.step, "environment");
        compare(mounted.name, "Mounted Example");
        compare(mounted.iconFile, "/tmp/.mount_x/example.png");

        // A hint at a file that is not installed names nothing, and the
        // command line is asked next.
        compare(found([entry("org.example.Cmd", { execString: "example-cmd" })],
                      { appId: "x", cmdline: "example-cmd",
                        desktopHint: { variable: "BAMF_DESKTOP_FILE_HINT", path: "/nowhere/y.desktop", id: "" } }),
                "org.example.Cmd@commandLine");
    }

    // 6. The command line against Exec, in Plasma's four ways: the whole
    // line; without the program's directory; without the arguments; without
    // both.
    function test_the_command_line_four_ways() {
        const entries = [
            entry("org.example.Whole", { execString: "/opt/example/whole --flag" }),
            entry("org.example.Tail", { execString: "tail-prog --flag" }),
            entry("org.example.Bare", { execString: "/usr/bin/bare-prog" }),
            entry("org.example.Short", { execString: "short-prog" })
        ];
        compare(found(entries, { appId: "x", cmdline: "/opt/example/whole --flag" }), "org.example.Whole@commandLine");
        compare(found(entries, { appId: "x", cmdline: "/usr/lib/tail-prog --flag" }), "org.example.Tail@commandLine");
        compare(found(entries, { appId: "x", cmdline: "/usr/bin/bare-prog --some file" }), "org.example.Bare@commandLine");
        compare(found(entries, { appId: "x", cmdline: "/usr/lib/short-prog --some file" }), "org.example.Short@commandLine");
        // Exactly: an Exec line is not a pattern, and case counts.
        compare(found(entries, { appId: "x", cmdline: "Short-Prog" }), "none");
        compare(found(entries, { appId: "x", cmdline: "short-prog2" }), "none");
    }

    // An interpreter is not the program: what it runs is.
    function test_past_an_interpreter() {
        const entries = [entry("org.example.Script", { execString: "example-script" })];
        compare(found(entries, { appId: "x", cmdline: "/usr/bin/perl /usr/bin/example-script --go" }),
                "org.example.Script@commandLine");
        // An interpreter alone: nothing, and no end-less search.
        compare(found(entries, { appId: "x", cmdline: "perl" }), "none");
        compare(found(entries, { appId: "x", cmdline: "/usr/bin/perl" }), "none");
    }

    // The last resort: no entry, but the command is a program on PATH -- and
    // the window is named after its process, with nothing to draw but its own
    // icon.
    function test_named_after_its_process_when_the_command_is_a_program() {
        const app = match([], { appId: "some.class", title: "Doc", cmdline: "/opt/example/bin/tool --x",
                                processName: "tool", executables: ["/opt/example/bin/tool"] });
        compare(app.step, "process");
        compare(app.name, "tool");
        compare(app.entry, null);
        compare(app.key, "class:some.class");
        // Not a program, or no process name: nothing.
        compare(found([], { appId: "c", cmdline: "C:\\Programs\\Example App\\app.exe", processName: "C:\\Programs\\Example App\\app.exe",
                            executables: [] }), "none");
        compare(found([], { appId: "c", cmdline: "tool", processName: "", executables: ["tool"] }), "none");
        // After an interpreter, the program it runs is the one asked about.
        compare(match([], { appId: "c", cmdline: "perl /opt/example/run.pl", processName: "perl",
                            executables: ["perl", "/opt/example/run.pl"] }).name, "perl");
        compare(found([], { appId: "c", cmdline: "perl /opt/example/run.pl", processName: "perl",
                            executables: ["perl"] }), "none");
    }

    // With neither an app id nor an instance name Plasma does not look at all,
    // not even at the process; with only an instance name the steps about the
    // app id are skipped and the process is still asked.
    function test_nothing_to_go_on() {
        const entries = [entry("org.example.Cmd", { execString: "example-cmd", startupClass: "inst" })];
        compare(found(entries, { cmdline: "example-cmd" }), "none");
        compare(found(entries, { resourceName: "inst", cmdline: "example-cmd" }), "org.example.Cmd@commandLine");
    }

    // ---- the order -------------------------------------------------------

    // One window fitting every step, and the entries each step would find.
    // Taking away the entry a step found hands the window to the next one.
    function test_each_step_before_the_next() {
        const all = [
            entry("by-startup-class", { startupClass: "example-app" }),
            entry("example-app"),
            entry("by-name", { name: "Example-App" }),
            entry("by-hint"),
            entry("by-exec", { execString: "example-app-bin" })
        ];
        const win = {
            appId: "example-app", resourceName: "example-inst",
            desktopHint: { variable: "BAMF_DESKTOP_FILE_HINT", path: "/apps/by-hint.desktop", id: "by-hint" },
            cmdline: "/usr/bin/example-app-bin", processName: "example-app-bin", executables: ["/usr/bin/example-app-bin"]
        };
        const expected = ["by-startup-class@startupClass", "example-app@id", "by-name@name",
                          "by-hint@environment", "by-exec@commandLine", "class:example-app@process"];
        let entries = all.slice();
        for (const want of expected) {
            compare(found(entries, win), want);
            entries = entries.slice(1);
        }
    }

    // A path in the app id comes after StartupWMClass and before the id.
    function test_a_path_between_the_class_and_the_id() {
        const path = "/opt/example/example-app.desktop";
        const file = { path: path, name: "From File" };
        compare(found([entry("by-class", { startupClass: path })], { appId: path, appIdFile: file }), "by-class@startupClass");
        compare(found([entry(path)], { appId: path, appIdFile: file }), `file:${path}@path`);
    }

    // The index is a value the shell keeps in a property; it has to survive
    // being kept there.
    property var kept: null
    function test_the_index_survives_a_property() {
        kept = AppMatch.index([entry("org.example.Viewer", { startupClass: "viewer" })]);
        compare(AppMatch.match(window({ appId: "viewer" }), kept, null).entry.id, "org.example.Viewer");
    }

    // ---- what is drawn, and what it is called ----------------------------

    function theme(name) {
        return name === "org.example.themed";
    }

    function test_the_icon_in_plasmas_order() {
        const own = window({ appId: "Example.Class", iconPath: "/run/icons/0x1-abc.png" });
        const themed = AppMatch.installed(entry("x", { icon: "org.example.themed" }));
        const absolute = AppMatch.installed(entry("x", { icon: "/opt/example/icon.png" }));
        const missing = AppMatch.installed(entry("x", { icon: "org.example.not-in-theme" }));

        // The application's icon from the theme, even when the window has one.
        compare(AppMatch.icon(themed, own, theme), { name: "org.example.themed", file: "" });
        // As a path.
        compare(AppMatch.icon(absolute, own, theme).file, "/opt/example/icon.png");
        // Beside a desktop file read from disk.
        const mounted = AppMatch.match(window({ appId: "m", desktopHint: { variable: "APPDIR", path: "/m/x.desktop",
                                                                             icon: "x", iconFile: "/m/x.png" } }),
                                       AppMatch.index([]), null);
        compare(AppMatch.icon(mounted, own, theme).file, "/m/x.png");
        // An application with none the theme has, or no application: the
        // window's own.
        compare(AppMatch.icon(missing, own, theme).file, "/run/icons/0x1-abc.png");
        compare(AppMatch.icon(null, own, theme).file, "/run/icons/0x1-abc.png");
        // Nothing of its own either: the theme, by desktop file or class.
        compare(AppMatch.icon(null, window({ appId: "Example.Class" }), theme), { name: "example.class", file: "" });
        compare(AppMatch.icon(missing, window({ desktopFile: "org.example.df" }), theme), { name: "org.example.df", file: "" });
    }

    function test_the_name_and_else_the_title() {
        compare(AppMatch.name(AppMatch.installed(entry("x", { name: "Example Viewer" })), window()), "Example Viewer");
        compare(AppMatch.name(null, window({ title: "A document", appId: "some_class_42" })), "A document");
        compare(AppMatch.name(null, window({ title: "", appId: "some_class_42" })), "some_class_42");
    }

    function test_windows_group_by_application_else_by_app_id() {
        const app = AppMatch.installed(entry("org.example.Viewer"));
        compare(AppMatch.groupKey(app, window({ appId: "a" })), "org.example.Viewer");
        compare(AppMatch.groupKey(null, window({ appId: "a", desktopFile: "b" })), "class:b");
    }
}
