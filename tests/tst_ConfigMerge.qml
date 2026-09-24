// Tests for what a flush writes.
//
// The profile is a sparse delta against the shipped defaults, so choosing the
// default value for a setting REMOVES its key rather than writing it. That is
// the case these tests exist for: a merge with the file that does not know a
// key was dropped brings it straight back, and the setting silently refuses to
// change. Picking "auto" for the theme did nothing for exactly this reason.

import QtQuick
import QtTest
import qs.domain.config.merge

TestCase {
    name: "ConfigMerge"

    // The version is the writer's business: it is on disk and never in our own
    // copy. Comparing the two shapes made every write look like a hand edit.
    function test_the_version_alone_is_not_a_change() {
        verify(!ConfigMerge.changedOnDisk({ schemaVersion: 1, theme: { mode: "light" } },
                                          { theme: { mode: "light" } }));
    }

    function test_a_real_change_is_a_change() {
        verify(ConfigMerge.changedOnDisk({ schemaVersion: 1, theme: { mode: "dark" } },
                                         { theme: { mode: "light" } }));
    }

    function test_an_added_key_is_a_change() {
        verify(ConfigMerge.changedOnDisk({ schemaVersion: 1, theme: { mode: "light" }, panel: { thickness: 40 } },
                                         { theme: { mode: "light" } }));
    }

    function test_nothing_on_either_side() {
        verify(!ConfigMerge.changedOnDisk({ schemaVersion: 1 }, {}));
    }

    // Nobody else wrote: what we hold is what goes out, untouched.
    function test_an_unchanged_file_leaves_our_copy_alone() {
        const ours = { panel: { thickness: 44 } };
        const out = ConfigMerge.flushData({ schemaVersion: 1, panel: { thickness: 38 } },
                                          { panel: { thickness: 38 } }, ours, []);
        compare(out.panel.thickness, 44);
    }

    // The bug, stated: the file still says light because that is what we wrote
    // last time. Choosing "auto" drops the key, and the flush must not undrop
    // it.
    function test_a_dropped_key_is_not_resurrected_by_the_file() {
        const onDisk = { schemaVersion: 1, theme: { mode: "light" }, panel: { thickness: 38 } };
        const lastParsed = { theme: { mode: "light" } };
        const ours = { panel: { thickness: 38 } };   // theme.mode already unset
        const out = ConfigMerge.flushData(onDisk, lastParsed, ours, ["theme.mode"]);
        verify(out.theme === undefined || out.theme.mode === undefined);
    }

    // A key somebody else added while we had the window open survives.
    function test_what_the_file_gained_is_kept() {
        const out = ConfigMerge.flushData({ schemaVersion: 1, panel: { renderer: "plasma" } },
                                          {}, { theme: { mode: "dark" } }, []);
        compare(out.panel.renderer, "plasma");
        compare(out.theme.mode, "dark");
    }

    // Both wrote the same key: ours is the newer intention.
    function test_our_value_wins_the_same_key() {
        const out = ConfigMerge.flushData({ schemaVersion: 1, theme: { mode: "light" } },
                                          {}, { theme: { mode: "dark" } }, []);
        compare(out.theme.mode, "dark");
    }

    function test_a_dropped_key_is_dropped_even_nested_deep() {
        const out = ConfigMerge.flushData({ schemaVersion: 1, widgets: { clock: { showDate: false, format: "HH:mm" } } },
                                          {}, { widgets: { clock: { format: "HH:mm" } } },
                                          ["widgets.clock.showDate"]);
        compare(out.widgets.clock.format, "HH:mm");
        verify(out.widgets.clock.showDate === undefined);
    }

    // Dropping the only key under a parent takes the empty parent with it:
    // that is what keeps the file a delta rather than a husk of empty objects.
    function test_dropping_the_last_key_prunes_its_parent() {
        const out = ConfigMerge.flushData({ schemaVersion: 1, theme: { mode: "light" } },
                                          {}, {}, ["theme.mode"]);
        verify(out.theme === undefined);
    }

    // The merge is made on a copy: neither what was read nor our own copy is
    // changed by it, whichever of the two holds the key.
    function test_the_merge_changes_neither_side() {
        const onDisk = { schemaVersion: 1, panel: { renderer: "plasma", thickness: 38 } };
        const ours = { panel: { thickness: 44 } };
        const out = ConfigMerge.flushData(onDisk, {}, ours, []);
        compare(out.panel, { renderer: "plasma", thickness: 44 });
        compare(onDisk.panel, { renderer: "plasma", thickness: 38 });
        compare(ours, { panel: { thickness: 44 } });
    }

    function test_no_removals_is_not_an_error() {
        const out = ConfigMerge.flushData({ schemaVersion: 1, theme: { mode: "light" } }, {}, {}, undefined);
        compare(out.theme.mode, "light");
    }
}
