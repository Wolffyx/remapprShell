// Auto-tiling's arithmetic: kwin/tile/contents/ui/dwindle.js.
//
// The script runs inside kwin_wayland and is seen there only in the rig
// (dev/kwin-rig/scenarios/auto-tile.sh); where it puts each window is this
// tree, and the shape it gives KWin's tiles is `layout`, which the snap
// layouts' `build` turns into tiles -- checked here against the same
// stand-in tst_SnapLayouts.qml uses for KWin's.

import QtQuick
import QtTest
import "../kwin/tile/contents/ui/dwindle.js" as Dwindle
import "../kwin/snap/contents/ui/layouts.js" as Layouts

TestCase {
    name: "Dwindle"

    // A screen of 1920x1080.
    readonly property real wide: 16 / 9

    function at(tree, id) {
        const p = Dwindle.places(tree).find(p => p.id === id);
        return p ? [p.rect.x, p.rect.y, p.rect.width, p.rect.height].map(v => Math.round(v * 1000) / 1000).join(",") : "none";
    }

    // Windows opened one after another, each splitting the one before.
    function opened(names, aspect) {
        let tree = null;
        let last = "";
        for (const n of names) {
            tree = Dwindle.insert(tree, n, last, aspect);
            last = n;
        }
        return tree;
    }

    function test_one_window_is_the_whole_screen() {
        compare(at(opened(["a"], wide), "a"), "0,0,1,1");
    }

    function test_each_window_splits_the_last_along_its_longer_side() {
        const tree = opened(["a", "b", "c", "d"], wide);
        compare(at(tree, "a"), "0,0,0.5,1");
        compare(at(tree, "b"), "0.5,0,0.5,0.5");
        compare(at(tree, "c"), "0.5,0.5,0.25,0.5");
        compare(at(tree, "d"), "0.75,0.5,0.25,0.5");
    }

    // On a portrait screen the first split is one above the other.
    function test_a_tall_screen_splits_across_first() {
        const tree = opened(["a", "b"], 9 / 16);
        compare(at(tree, "a"), "0,0,1,0.5");
        compare(at(tree, "b"), "0,0.5,1,0.5");
    }

    // The longer side is the longer in pixels: half of a wide screen is half
    // as wide as it is tall in fractions, and still the wider in pixels on
    // one wider than 2:1.
    function test_the_longer_side_is_measured_in_pixels() {
        const ultrawide = opened(["a", "b", "c"], 3440 / 1440);
        compare(at(ultrawide, "b"), "0.5,0,0.25,1");
        compare(at(ultrawide, "c"), "0.75,0,0.25,1");
    }

    function test_a_window_splits_the_target_it_is_given() {
        let tree = opened(["a", "b"], wide);
        tree = Dwindle.insert(tree, "c", "a", wide);
        compare(at(tree, "a"), "0,0,0.5,0.5");
        compare(at(tree, "c"), "0,0.5,0.5,0.5");
        compare(at(tree, "b"), "0.5,0,0.5,1");
    }

    function test_an_unknown_target_splits_the_last_window() {
        const tree = Dwindle.insert(opened(["a", "b"], wide), "c", "gone", wide);
        compare(at(tree, "c"), "0.5,0.5,0.5,0.5");
    }

    function test_a_window_already_in_is_not_added_twice() {
        const tree = opened(["a", "b"], wide);
        compare(Dwindle.insert(tree, "a", "b", wide), tree);
    }

    function test_a_window_gone_leaves_its_half_to_its_sibling() {
        let tree = opened(["a", "b", "c"], wide);
        tree = Dwindle.remove(tree, "b");
        compare(at(tree, "c"), "0.5,0,0.5,1");
        compare(at(tree, "a"), "0,0,0.5,1");
        tree = Dwindle.remove(tree, "a");
        compare(at(tree, "c"), "0,0,1,1");
        compare(Dwindle.remove(tree, "c"), null);
    }

    function test_the_old_tree_is_left_alone() {
        const before = opened(["a", "b"], wide);
        Dwindle.insert(before, "c", "b", wide);
        Dwindle.remove(before, "a");
        compare(Dwindle.ids(before).join(" "), "a b");
    }

    function test_swap_trades_places_and_keeps_the_splits() {
        const tree = Dwindle.swap(opened(["a", "b", "c"], wide), "a", "c");
        compare(at(tree, "c"), "0,0,0.5,1");
        compare(at(tree, "a"), "0.5,0.5,0.5,0.5");
        compare(at(tree, "b"), "0.5,0,0.5,0.5");
    }

    function test_the_neighbour_each_way() {
        const tree = opened(["a", "b", "c", "d"], wide);
        compare(Dwindle.neighbour(tree, "d", "left", wide), "c");
        compare(Dwindle.neighbour(tree, "c", "left", wide), "a");
        compare(Dwindle.neighbour(tree, "c", "up", wide), "b");
        compare(Dwindle.neighbour(tree, "b", "down", wide), "c");
        // b and c are as far off a's middle to the side; c is the nearer.
        compare(Dwindle.neighbour(tree, "a", "right", wide), "c");
        compare(Dwindle.neighbour(tree, "a", "left", wide), null);
        compare(Dwindle.neighbour(tree, "nobody", "left", wide), null);
        compare(Dwindle.neighbour(tree, "a", "sideways", wide), null);
    }

    // Right from a window beside a stack goes to the part of the stack level
    // with it, not to whichever is nearest corner to corner.
    function test_a_step_aside_counts_double() {
        let tree = Dwindle.insert(Dwindle.insert(null, "a", "", wide), "b", "a", wide);
        tree = Dwindle.insert(tree, "c", "b", wide);
        tree = Dwindle.insert(tree, "d", "a", wide);
        compare(Dwindle.neighbour(tree, "d", "right", wide), "c");
        compare(Dwindle.neighbour(tree, "a", "right", wide), "b");
    }

    function test_move_goes_past_the_neighbour() {
        const tree = opened(["a", "b"], wide);
        const moved = Dwindle.move(tree, "a", "right", wide);
        compare(at(moved, "b"), "0,0,0.5,1");
        compare(at(moved, "a"), "0.5,0,0.5,1");
        compare(Dwindle.move(tree, "a", "left", wide), tree);
    }

    function test_move_up_splits_the_window_above() {
        const tree = Dwindle.move(opened(["a", "b", "c"], wide), "c", "up", wide);
        compare(at(tree, "c"), "0.5,0,0.5,0.5");
        compare(at(tree, "b"), "0.5,0.5,0.5,0.5");
    }

    // A resize moved the edge between a and the rest; the tree takes it.
    function test_adopt_takes_the_edges_kwin_moved() {
        const tree = opened(["a", "b", "c"], wide);
        const kwin = { a: { x: 0, y: 0, width: 0.6, height: 1 },
                       b: { x: 0.6, y: 0, width: 0.4, height: 0.3 },
                       c: { x: 0.6, y: 0.3, width: 0.4, height: 0.7 } };
        const adopted = Dwindle.adopt(tree, id => kwin[id]);
        compare(at(adopted, "a"), "0,0,0.6,1");
        compare(at(adopted, "b"), "0.6,0,0.4,0.3");
        compare(at(adopted, "c"), "0.6,0.3,0.4,0.7");
    }

    function test_adopt_keeps_a_split_with_a_window_out_of_its_tile() {
        const tree = opened(["a", "b"], wide);
        const adopted = Dwindle.adopt(tree, id => id === "a" ? { x: 0, y: 0, width: 0.7, height: 1 } : null);
        compare(at(adopted, "a"), "0,0,0.5,1");
    }

    function test_adopt_never_leaves_a_side_nothing() {
        const tree = opened(["a", "b"], wide);
        const adopted = Dwindle.adopt(tree, id => id === "a" ? { x: 0, y: 0, width: 0.001, height: 1 }
                                                             : { x: 0.001, y: 0, width: 0.999, height: 1 });
        compare(at(adopted, "a"), "0,0,0.05,1");
    }

    function test_no_layout_for_one_window_or_none() {
        compare(Dwindle.layout(null), null);
        compare(Dwindle.layout(opened(["a"], wide)), null);
    }

    // The layout's zones are the windows' places, every one of them.
    function test_the_layout_has_every_window_place_as_a_zone() {
        for (const n of [2, 3, 4, 5, 7]) {
            const names = ["a", "b", "c", "d", "e", "f", "g"].slice(0, n);
            for (const aspect of [wide, 9 / 16, 3440 / 1440]) {
                const tree = opened(names, aspect);
                const zones = Layouts.zonesOf(Dwindle.layout(tree));
                verify(Layouts.sameZones(zones, Dwindle.places(tree).map(p => p.rect)), `${n} windows at ${aspect}`);
            }
        }
    }

    // A split inside a split the same way is folded into it: KWin's tiles
    // add a sibling where a split would nest the same way.
    function test_a_split_the_same_way_is_folded_into_its_parent() {
        const shape = Dwindle.layout(opened(["a", "b", "c"], 3440 / 1440));
        compare(shape.dir, "h");
        compare(shape.parts.map(p => typeof p === "number" ? p : "node").join(" "), "0.5 0.25 0.25");
    }

    // ---- into tiles, through the snap layouts' build ------------------------

    // KWin's tiles as tst_SnapLayouts.qml has them: a split leaf becomes two
    // halves; a leaf whose parent is split the same way gains a sibling.
    Component {
        id: tileType

        QtObject {
            id: tile
            property var parentTile: null
            property var tiles: []
            property int dir: 0
            property var geometry: ({ x: 0, y: 0, width: 1, height: 1 })
            property var relativeGeometry: geometry
            onRelativeGeometryChanged: geometry = relativeGeometry

            function make(g) {
                return tileType.createObject(null, { parentTile: tile, geometry: g, relativeGeometry: g });
            }
            function split(d) {
                const g = tile.geometry;
                const p = tile.parentTile;
                const first = d === 1 ? { x: g.x, y: g.y, width: g.width / 2, height: g.height }
                                      : { x: g.x, y: g.y, width: g.width, height: g.height / 2 };
                const second = d === 1 ? { x: g.x + g.width / 2, y: g.y, width: g.width / 2, height: g.height }
                                       : { x: g.x, y: g.y + g.height / 2, width: g.width, height: g.height / 2 };
                if (p && p.dir === d && tile.tiles.length === 0) {
                    tile.relativeGeometry = first;
                    const kids = p.tiles.slice();
                    kids.splice(kids.indexOf(tile) + 1, 0, p.make(second));
                    p.tiles = kids;
                    return;
                }
                tile.dir = d;
                tile.tiles = [tile.make(first), tile.make(second)];
            }
            function remove() {
                const p = tile.parentTile;
                p.tiles = p.tiles.filter(t => t !== tile);
            }
        }
    }

    function test_the_tree_becomes_tiles_with_a_leaf_for_each_window() {
        for (const aspect of [wide, 3440 / 1440]) {
            const top = tileType.createObject(null);
            const tree = opened(["a", "b", "c", "d", "e"], aspect);
            verify(Layouts.build(top, Dwindle.layout(tree), { h: 1, v: 2 }), `built at ${aspect}`);
            for (const p of Dwindle.places(tree))
                verify(Layouts.leafFor(top, p.rect) !== null, `${p.id} has a tile at ${aspect}`);
            compare(Layouts.leaves(top).length, 5);
        }
    }
}
