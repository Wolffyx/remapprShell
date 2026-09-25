// Tests for what the installer window says to setup.sh, and what it reads
// back.
//
// The flags have to be every question answered -- one left out and setup.sh
// asks it, of nobody, and takes that as no -- and the progress has to settle
// the right task when two steps share a name.

import QtQuick
import QtTest
import qs.domain.installer

TestCase {
    name: "InstallerEvents"

    readonly property var keys: [
        { id: "launcher", key: "Meta", on: true },
        { id: "search", key: "Meta+Space", on: true },
        { id: "clipboard", key: "Meta+V", on: false }
    ]

    function argAfter(args, flag) {
        const i = args.indexOf(flag);
        return i < 0 ? undefined : args[i + 1];
    }

    function test_defaults_are_setups() {
        const a = InstallerEvents.defaults(keys);
        compare(a.mode, "copy");
        compare(a.renderer, "quickshell");
        compare(a.keys.join(" "), "launcher search");
        compare(a.windowList, true);
        compare(a.snapshot, true);
    }

    function test_every_question_is_answered() {
        const args = InstallerEvents.setupArgs(InstallerEvents.defaults(keys));
        for (const flag of ["--mode", "--renderer", "--keys", "--alttab", "--window-list",
                            "--previews", "--theme", "--autostart"])
            verify(args.indexOf(flag) >= 0, `${flag} missing`);
        verify(args.indexOf("--unattended") >= 0);
        verify(args.indexOf("--progress") >= 0);
        compare(argAfter(args, "--keys"), "launcher search");
        compare(argAfter(args, "--window-list"), "yes");
        verify(args.indexOf("--no-snapshot") < 0);
    }

    function test_no_keys_is_said_as_none() {
        const a = InstallerEvents.defaults(keys);
        a.keys = [];
        compare(argAfter(InstallerEvents.setupArgs(a), "--keys"), "none");
    }

    function test_no_restore_point_is_passed_on() {
        const a = InstallerEvents.defaults(keys);
        a.snapshot = false;
        verify(InstallerEvents.setupArgs(a).indexOf("--no-snapshot") >= 0);
    }

    function test_progress_lines_and_the_rest() {
        compare(InstallerEvents.parse("::step installing").kind, "step");
        compare(InstallerEvents.parse("::step Meta+V -> clipboard").text, "Meta+V -> clipboard");
        compare(InstallerEvents.parse("::done 2").kind, "done");
        compare(InstallerEvents.parse("::exit 1").kind, "exit");
        compare(InstallerEvents.parse("==> installing"), null);
        compare(InstallerEvents.parse(""), null);
        compare(InstallerEvents.parse(undefined), null);
    }

    function test_tasks_start_and_settle() {
        let t = InstallerEvents.apply([], InstallerEvents.parse("::step installing"));
        compare(t.length, 1);
        compare(t[0].state, "running");
        t = InstallerEvents.apply(t, InstallerEvents.parse("::ok installing"));
        compare(t[0].state, "done");
        t = InstallerEvents.apply(t, InstallerEvents.parse("::step the panel"));
        t = InstallerEvents.apply(t, InstallerEvents.parse("::fail the panel"));
        compare(t[1].state, "failed");
        compare(t[0].state, "done");
    }

    // Two steps of one name: each settles its own, the latest running first.
    function test_a_repeated_name_settles_the_running_one() {
        let t = [];
        for (const line of ["::step build", "::ok build", "::step build", "::fail build"])
            t = InstallerEvents.apply(t, InstallerEvents.parse(line));
        compare(t[0].state, "done");
        compare(t[1].state, "failed");
    }

    function test_a_new_array_every_time() {
        const before = [{ label: "x", state: "running" }];
        const after = InstallerEvents.apply(before, InstallerEvents.parse("::ok x"));
        verify(after !== before);
        compare(before[0].state, "running");
    }

    function test_failures_from_done() {
        compare(InstallerEvents.failures(InstallerEvents.parse("::done 0")), 0);
        compare(InstallerEvents.failures(InstallerEvents.parse("::done 2")), 2);
        compare(InstallerEvents.failures(InstallerEvents.parse("::ok x")), -1);
    }
}
