// Tests for what the keyboard widget shows: KWin's layouts as it gives them,
// the label drawn for one, and which one a click or a notch moves to.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "KeyboardLayouts"

    // What KWin returned here: a(sss), one layout, no label of the user's.
    function test_layouts_as_kwin_gives_them() {
        const l = KeyboardLayouts.keyboardLayouts([["us", "", "English (US)"], ["de", "", "German"], ["bad"]]);
        compare(l.length, 2);
        compare(l[1].long, "German");
        compare(KeyboardLayouts.keyboardLayouts(null).length, 0);
    }

    function test_layout_label() {
        compare(KeyboardLayouts.layoutLabel({ short: "us", display: "", long: "English (US)" }), "US");
        compare(KeyboardLayouts.layoutLabel({ short: "ru", display: "Рус", long: "Russian" }), "Рус");
        compare(KeyboardLayouts.layoutLabel(null), "");
    }

    function test_cycle_wraps_both_ways() {
        compare(KeyboardLayouts.cycleIndex(2, 3, 1), 0);
        compare(KeyboardLayouts.cycleIndex(0, 3, -1), 2);
        compare(KeyboardLayouts.cycleIndex(1, 3, -4), 0);
        compare(KeyboardLayouts.cycleIndex(-1, 3, 1), 1);
        compare(KeyboardLayouts.cycleIndex(0, 0, 1), -1);
    }
}
