// The snap layout editor's arithmetic: qs.domain.windows.snap's SnapEditor.
//
// What it makes is read by kwin/snap's layouts.js, so every tree here is
// also put to layouts.js's own check: a layout the editor draws is one the
// panel shows, and one KWin's tiles can be.

import QtQuick
import QtTest
import qs.domain.windows.snap
import "../kwin/snap/contents/ui/layouts.js" as Layouts

TestCase {
    name: "SnapEditor"

    function valid(tree, what) {
        compare(Layouts.treeError(tree), "", `${what}: ${JSON.stringify(tree)}`);
    }

    function zoneRects(tree) {
        return SnapEditor.zones(tree).map(z => ({ x: z.x, y: z.y, width: z.width, height: z.height }));
    }

    // ---- what it shares with the script ------------------------------------

    function test_the_presets_are_the_scripts() {
        compare(SnapEditor.presets.map(p => p.id), Layouts.PRESETS.map(p => p.id));
        for (const p of SnapEditor.presets)
            compare(JSON.stringify(p.tree), JSON.stringify(Layouts.PRESETS.find(q => q.id === p.id).tree), p.id);
    }

    function test_the_limits_are_the_scripts() {
        compare(SnapEditor.minZone, Layouts.MIN_ZONE);
        compare(SnapEditor.maxLayouts, Layouts.MAX_CUSTOM);
    }

    function test_zones_in_the_scripts_order() {
        for (const p of SnapEditor.presets)
            verify(Layouts.sameZones(zoneRects(p.tree), Layouts.zonesOf(p.tree)), p.id);
        compare(SnapEditor.zones(SnapEditor.presets[3].tree).map(z => z.path), [[0], [1, 0], [1, 1]]);
    }

    // ---- splitting -----------------------------------------------------------

    function test_a_blank_is_no_layout_until_split() {
        verify(!SnapEditor.isLayout(SnapEditor.blank()));
        const halves = SnapEditor.split(SnapEditor.blank(), [0], "h");
        compare(halves, { dir: "h", parts: [0.5, 0.5] });
        compare(SnapEditor.split(SnapEditor.blank(), [0], "v"), { dir: "v", parts: [0.5, 0.5] });
        verify(SnapEditor.isLayout(halves));
    }

    // A zone split the way its split goes becomes two parts of that split,
    // not a split inside it: KWin would add a sibling instead.
    function test_a_split_the_same_way_is_folded_in() {
        const t = SnapEditor.split({ dir: "h", parts: [0.5, 0.5] }, [1], "h");
        compare(t, { dir: "h", parts: [0.5, 0.25, 0.25] });
        valid(t, "folded");
    }

    function test_a_split_the_other_way_nests() {
        const t = SnapEditor.split({ dir: "h", parts: [0.5, 0.5] }, [1], "v");
        compare(t, { dir: "h", parts: [0.5, { size: 0.5, dir: "v", parts: [0.5, 0.5] }] });
        valid(t, "nested");
    }

    function test_the_original_is_never_changed() {
        const t = { dir: "h", parts: [0.5, 0.5] };
        SnapEditor.split(t, [0], "v");
        SnapEditor.merge(t, [0]);
        SnapEditor.moveEdge(t, SnapEditor.edges(t)[0], 0.7);
        compare(t, { dir: "h", parts: [0.5, 0.5] });
    }

    // KWin makes no tile of 0.15 of the screen or less, and the editor none
    // under 0.155: a zone 0.31 wide splits into two of 0.155, and one
    // narrower does not split.
    function test_no_split_under_the_smallest_zone() {
        const t = { dir: "h", parts: [0.31, 0.69] };
        verify(SnapEditor.canSplit(t, [0], "h"));
        verify(!SnapEditor.canSplit({ dir: "h", parts: [0.3, 0.7] }, [0], "h"));
        verify(SnapEditor.canSplit({ dir: "h", parts: [0.3, 0.7] }, [0], "v"));
        compare(SnapEditor.split({ dir: "h", parts: [0.3, 0.7] }, [0], "h"), { dir: "h", parts: [0.3, 0.7] });
        valid(SnapEditor.split(t, [0], "h"), "two of 0.155");
    }

    // As far as it goes: nothing more splits, and nothing it made is too
    // small.
    function test_splitting_until_nothing_splits() {
        let t = SnapEditor.blank();
        for (let i = 0; i < 20; ++i) {
            const z = SnapEditor.zones(t).find(z => SnapEditor.canSplit(t, z.path, "h"));
            if (z)
                t = SnapEditor.split(t, z.path, "h");
        }
        verify(SnapEditor.zones(t).length <= 6);
        valid(t, "split to the end");
        verify(SnapEditor.zones(t).every(z => !SnapEditor.canSplit(t, z.path, "h")));
    }

    // ---- merging -------------------------------------------------------------

    function test_a_merge_gives_the_room_to_the_zone_before() {
        compare(SnapEditor.merge({ dir: "h", parts: [0.25, 0.5, 0.25] }, [1]), { dir: "h", parts: [0.75, 0.25] });
        compare(SnapEditor.merge({ dir: "h", parts: [0.25, 0.5, 0.25] }, [0]), { dir: "h", parts: [0.75, 0.25] });
    }

    // Merging one of a stack of two leaves a zone, not a split of one, and
    // the last two merged are the blank screen again.
    function test_a_split_of_one_is_folded_away() {
        const stack = SnapEditor.presets[3].tree;
        compare(SnapEditor.merge(stack, [1, 1]), { dir: "h", parts: [0.5, 0.5] });
        compare(SnapEditor.merge({ dir: "h", parts: [0.5, 0.5] }, [1]), { dir: "h", parts: [1] });
        verify(!SnapEditor.canMerge(SnapEditor.blank(), [0]));
    }

    // The room goes to a split beside it: every zone in it grows that way.
    function test_a_merge_into_a_split_grows_it() {
        const t = SnapEditor.merge({ dir: "h", parts: [{ size: 0.5, dir: "v", parts: [0.5, 0.5] }, 0.25, 0.25] }, [1]);
        compare(t, { dir: "h", parts: [{ size: 0.75, dir: "v", parts: [0.5, 0.5] }, 0.25] });
        valid(t, "grown");
    }

    // And a whole screen left as one split the other way is that split.
    function test_the_root_becomes_the_split_left() {
        const t = SnapEditor.merge({ dir: "h", parts: [{ size: 0.5, dir: "v", parts: [0.5, 0.5] }, 0.5] }, [1]);
        compare(t, { dir: "v", parts: [0.5, 0.5] });
    }

    // ---- edges ---------------------------------------------------------------

    function test_the_edges_of_a_layout() {
        const e = SnapEditor.edges(SnapEditor.presets[4].tree);   // quarters
        compare(e.length, 3);
        compare([e[0].dir, e[0].position, e[0].height], ["h", 0.5, 1]);
        compare([e[1].dir, e[1].position, e[1].x, e[1].width], ["v", 0.5, 0, 0.5]);
        compare([e[2].dir, e[2].position, e[2].x], ["v", 0.5, 0.5]);
    }

    function test_an_edge_moves_both_its_zones() {
        const t = { dir: "h", parts: [0.5, 0.5] };
        const moved = SnapEditor.moveEdge(t, SnapEditor.edges(t)[0], 0.6);
        fuzzyCompare(moved.parts[0], 0.6, 1e-9);
        fuzzyCompare(moved.parts[1], 0.4, 1e-9);
    }

    function test_an_edge_lands_on_a_step() {
        const t = { dir: "h", parts: [0.5, 0.5] };
        const moved = SnapEditor.moveEdge(t, SnapEditor.edges(t)[0], 0.6612);
        fuzzyCompare(moved.parts[0], 0.66, 1e-9);
    }

    // An edge stops where a zone on either side would be under 0.155 -- for
    // a split beside it, where its own tightest zone would be.
    function test_an_edge_stops_at_the_smallest_zone() {
        const t = { dir: "h", parts: [0.5, 0.5] };
        const e = SnapEditor.edges(t)[0];
        fuzzyCompare(e.lo, 0.155, 1e-9);
        fuzzyCompare(e.hi, 0.845, 1e-9);
        fuzzyCompare(SnapEditor.moveEdge(t, e, 0.01).parts[0], 0.155, 1e-9);
        fuzzyCompare(SnapEditor.moveEdge(t, e, 0.99).parts[1], 0.155, 1e-9);

        // The right half a stack, its top split in two side by side: the
        // edge between the halves stops where those two would be 0.155 each.
        const deep = { dir: "h", parts: [0.5, { size: 0.5, dir: "v", parts: [{ size: 0.5, dir: "h", parts: [0.5, 0.5] }, 0.5] }] };
        valid(deep, "deep");
        const d = SnapEditor.edges(deep)[0];
        fuzzyCompare(d.hi, 0.69, 1e-9);
        valid(SnapEditor.moveEdge(deep, d, 0.95), "pushed to its end");
    }

    function test_an_inner_edge_is_measured_in_its_own_split() {
        const t = SnapEditor.presets[3].tree;   // one beside two
        const e = SnapEditor.edges(t).find(e => e.dir === "v");
        compare([e.position, e.extent, e.x, e.width], [0.5, 1, 0.5, 0.5]);
        const moved = SnapEditor.moveEdge(t, e, 0.3);
        fuzzyCompare(moved.parts[1].parts[0], 0.3, 1e-9);
        valid(moved, "inner edge moved");
    }

    // Every way the tree can be changed, a few hundred times, from every
    // preset: nothing it makes is anything layouts.js refuses.
    function test_whatever_is_drawn_is_a_layout() {
        let seed = 7;
        const next = n => (seed = (seed * 1103515245 + 12345) % 2147483648) % n;
        for (const p of SnapEditor.presets) {
            let t = p.tree;
            for (let i = 0; i < 300; ++i) {
                const zones = SnapEditor.zones(t);
                const z = zones[next(zones.length)];
                const edges = SnapEditor.edges(t);
                const ops = [
                    () => SnapEditor.split(t, z.path, "h"),
                    () => SnapEditor.split(t, z.path, "v"),
                    () => SnapEditor.merge(t, z.path),
                    () => edges.length ? SnapEditor.moveEdge(t, edges[next(edges.length)], next(1000) / 1000) : t
                ];
                t = ops[next(ops.length)]();
                if (SnapEditor.isLayout(t))
                    valid(SnapEditor.tidy(t), `${p.id}, step ${i}`);
            }
        }
    }

    // ---- turning it, and saving it -----------------------------------------

    function test_turned_on_its_side() {
        compare(SnapEditor.transpose(SnapEditor.presets[3].tree),
                { dir: "v", parts: [0.5, { size: 0.5, dir: "h", parts: [0.5, 0.5] }] });
        compare(JSON.stringify(SnapEditor.transpose(SnapEditor.presets[3].tree)),
                JSON.stringify(Layouts.transpose(Layouts.PRESETS[3].tree)));
    }

    function test_tidy_keeps_six_places() {
        const t = SnapEditor.tidy({ dir: "h", parts: [1 / 3, { size: 2 / 3, dir: "v", parts: [0.5, 0.5] }] });
        compare(JSON.stringify(t), '{"dir":"h","parts":[0.333333,{"size":0.666667,"dir":"v","parts":[0.5,0.5]}]}');
        valid(t, "tidied");
    }
}
