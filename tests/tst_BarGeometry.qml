// Tests for what BarWidget works out for the widgets on the panel: the tile
// they draw on, which way the panel runs, and which of their parts is under
// the pointer.
//
// Twenty widgets used to write these out for themselves. Now that they read
// them here, a slip here is a slip everywhere at once -- a tile a pixel off on
// every button, or a hover that lands on the neighbour of what is under the
// pointer -- so the numbers are pinned: the same ones the widgets computed.

import QtQuick
import QtTest
import qs.ui.primitives

TestCase {
    name: "BarGeometry"

    component Widget: BarWidget {
        bar: null
        widgetConfig: ({})
        screenName: "TEST-1"
    }

    Component {
        id: widgetFactory
        Widget { }
    }

    function widget(bar) {
        const w = createTemporaryObject(widgetFactory, this);
        w.bar = bar;
        return w;
    }

    // Parts along a row: 30, 50 and 20 wide, 10 apart -- so at 0, 40 and 100.
    Component {
        id: rowFactory
        Row {
            property alias parts: parts
            spacing: 10
            Repeater {
                id: parts
                model: [30, 50, 20]
                Item {
                    required property int modelData
                    width: modelData
                    height: modelData
                }
            }
        }
    }

    // And down a column, the same sizes: at 0, 40 and 100.
    Component {
        id: columnFactory
        Column {
            property alias parts: parts
            spacing: 10
            Repeater {
                id: parts
                model: [30, 50, 20]
                Item {
                    required property int modelData
                    width: modelData
                    height: modelData
                }
            }
        }
    }

    // ---- the panel -----------------------------------------------------------

    // No panel yet: a 40 px one along an edge, as every widget assumed.
    function test_without_a_panel() {
        const w = widget(null);
        compare(w.barThickness, 40);
        compare(w.barVertical, false);
        compare(w.unit, 40 / 64);
    }

    function test_the_panel_says_which_way_it_runs() {
        compare(widget({ thickness: 64, horizontal: true }).barVertical, false);
        compare(widget({ thickness: 64, horizontal: false }).barVertical, true);
        // A bar that does not say is taken to run along an edge.
        compare(widget({ thickness: 64 }).barVertical, false);
    }

    // The tile is the design's 40 at 64 px, scaled, and never under 22 --
    // `Math.max(22, Math.round(40 * unit))`, as the widgets had it.
    function test_the_tile_follows_the_thickness() {
        const cases = [[64, 40], [44, 28], [40, 25], [48, 30], [80, 50], [32, 22], [20, 22]];
        for (const [thickness, tile] of cases)
            compare(widget({ thickness: thickness, horizontal: true }).tileSize, tile, `at ${thickness}px`);
    }

    // ---- which part -----------------------------------------------------------

    // Each part reaches half the spacing out either side, so the gap between
    // two is split between them and nothing falls through it.
    function test_the_part_under_the_pointer() {
        const w = widget(null);
        const row = createTemporaryObject(rowFactory, this);
        const at = p => w.indexAlong(row.parts, p, row.spacing, false);
        compare(at(-6), -1);
        compare(at(-5), 0);
        compare(at(34.9), 0);
        compare(at(35), 1);
        compare(at(94.9), 1);
        compare(at(95), 2);
        compare(at(124.9), 2);
        compare(at(125), -1);
    }

    // A widget whose parts do not start at its own edge -- the status glyphs,
    // centred in their tile -- measures from where they start.
    function test_measured_from_where_the_parts_start() {
        const w = widget(null);
        const row = createTemporaryObject(rowFactory, this);
        compare(w.indexAlong(row.parts, 20, row.spacing, false, 16), 0);
        compare(w.indexAlong(row.parts, 51, row.spacing, false, 16), 1);
        // Half the spacing before the first part still reaches it; the
        // widget's own margin before that does not.
        compare(w.indexAlong(row.parts, 11, row.spacing, false, 16), 0);
        compare(w.indexAlong(row.parts, 10, row.spacing, false, 16), -1);
    }

    function test_down_the_side_it_is_the_height_that_counts() {
        const w = widget(null);
        const column = createTemporaryObject(columnFactory, this);
        compare(w.indexAlong(column.parts, 36, column.spacing, true), 1);
        compare(w.indexAlong(column.parts, 36, column.spacing, false), 1);
        compare(w.indexAlong(column.parts, 96, column.spacing, true), 2);
        // Across, the column's parts all start at 0.
        compare(w.indexAlong(column.parts, 96, column.spacing, false), -1);
    }

    // The middle of a part, from the widget's start, for a tooltip or a popout
    // to point at; -1 for a part that is not there.
    function test_the_middle_of_a_part() {
        const w = widget(null);
        const row = createTemporaryObject(rowFactory, this);
        compare(w.centreAlong(row.parts, 0, false), 15);
        compare(w.centreAlong(row.parts, 1, false), 65);
        compare(w.centreAlong(row.parts, 2, false), 110);
        compare(w.centreAlong(row.parts, 1, false, 16), 81);
        compare(w.centreAlong(row.parts, -1, false), -1);
        compare(w.centreAlong(row.parts, 3, false), -1);

        const column = createTemporaryObject(columnFactory, this);
        compare(w.centreAlong(column.parts, 2, true), 110);
    }
}
