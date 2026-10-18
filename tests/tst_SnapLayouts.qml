// The snap layouts' arithmetic: kwin/snap/contents/ui/layouts.js.
//
// The script itself runs inside kwin_wayland and can only be seen there; what
// it draws and where it puts a window are these numbers, and they can be
// checked here. The tile half is checked against a stand-in that splits the
// way KWin 6.8's tiles were measured to: a split leaf becomes two halves, a
// split child of a tile split the same way gains a sibling, and sizing a
// child moves the edge its next sibling shares with it.

import QtQuick
import QtTest
import "../kwin/snap/contents/ui/layouts.js" as Layouts

TestCase {
    name: "SnapLayouts"

    readonly property var metrics: ({ card: 96, gapX: 14, gapY: 12, pad: 8, inset: 2 })

    function area(zones) {
        return zones.reduce((sum, z) => sum + z.width * z.height, 0);
    }

    function overlap(a, b) {
        const w = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
        const h = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
        return w > 1e-9 && h > 1e-9;
    }

    // ---- the layouts -------------------------------------------------------

    function test_six_layouts_in_the_order_windows_has_them() {
        compare(Layouts.presets(false).map(p => p.id).join(" "),
                "halves twoThirds thirds mainStack quarters wideCentre");
    }

    // Every zone of a layout is somewhere a window can go, and together they
    // are the whole screen: nothing left over, nothing counted twice.
    function test_every_layout_covers_the_screen_once() {
        for (const portrait of [false, true]) {
            for (const p of Layouts.presets(portrait)) {
                fuzzyCompare(area(p.zones), 1, 1e-9, `${p.id} covers it all`);
                for (let i = 0; i < p.zones.length; ++i)
                    for (let j = i + 1; j < p.zones.length; ++j)
                        verify(!overlap(p.zones[i], p.zones[j]), `${p.id}: zones ${i} and ${j} overlap`);
            }
        }
    }

    function test_zones_are_listed_depth_first() {
        const stack = Layouts.presets(false).find(p => p.id === "mainStack");
        compare(stack.zones.length, 3);
        compare(stack.zones[0], { x: 0, y: 0, width: 0.5, height: 1 });
        compare(stack.zones[1], { x: 0.5, y: 0, width: 0.5, height: 0.5 });
        compare(stack.zones[2], { x: 0.5, y: 0.5, width: 0.5, height: 0.5 });
    }

    // A portrait screen gets the same layouts turned on their side, as
    // Windows does: halves are top and bottom.
    function test_a_portrait_screen_stacks_them() {
        const halves = Layouts.presets(true)[0];
        compare(halves.zones[0], { x: 0, y: 0, width: 1, height: 0.5 });
        compare(halves.zones[1], { x: 0, y: 0.5, width: 1, height: 0.5 });
    }

    function test_the_same_zones_in_any_order() {
        const thirds = Layouts.presets(false)[2].zones;
        const kept = [{ x: 2 / 3, y: 0, width: 0.33333334, height: 1 },
                      { x: 0, y: 0, width: 1 / 3, height: 1 },
                      { x: 1 / 3, y: 0, width: 1 / 3, height: 1 }];
        verify(Layouts.sameZones(thirds, kept));
        verify(!Layouts.sameZones(thirds, kept.slice(1)));
        verify(!Layouts.sameZones(thirds, Layouts.presets(false)[5].zones));
    }

    // ---- the panel ---------------------------------------------------------

    function test_six_cards_make_two_rows_of_three() {
        const a = Layouts.arrange(Layouts.presets(false), 16 / 9, metrics);
        compare(a.cards.length, 6);
        compare(a.width, 2 * 8 + 3 * 96 + 2 * 14);
        compare(a.height, 2 * 8 + 2 * 54 + 12);
        compare(a.cards[3].x, a.cards[0].x);
        compare(a.cards[3].y, a.cards[0].y + 54 + 12);
    }

    // A layout of the user's own, from Meta+T, makes a seventh card, and the
    // panel goes to four columns rather than a third row of one.
    function test_a_seventh_card_widens_the_panel() {
        const list = Layouts.presets(false);
        list.unshift({ id: "kwin", tree: null, zones: [{ x: 0, y: 0, width: 0.2, height: 1 },
                                                       { x: 0.2, y: 0, width: 0.8, height: 1 }] });
        const a = Layouts.arrange(list, 16 / 9, metrics);
        compare(a.width, 2 * 8 + 4 * 96 + 3 * 14);
        compare(a.cards[4].y, a.cards[0].y + 54 + 12);
    }

    function test_cards_are_the_shape_of_the_screen() {
        const wide = Layouts.arrange(Layouts.presets(false), 16 / 9, metrics).cards[0];
        compare([wide.width, wide.height], [96, 54]);
        const tall = Layouts.arrange(Layouts.presets(true), 9 / 16, metrics).cards[0];
        compare([tall.width, tall.height], [54, 96]);
    }

    // Two zones side by side are exactly twice the inset apart, whatever a
    // third did to the rounding: a gap that wanders by a pixel shows.
    function test_neighbouring_zones_keep_one_gap() {
        const a = Layouts.arrange(Layouts.presets(false), 16 / 9, metrics);
        for (const card of a.cards) {
            for (const z of card.zones) {
                const right = card.zones.find(w => w.x > z.x + z.width && Math.abs(w.y - z.y) < 1);
                if (right)
                    compare(right.x - (z.x + z.width), 2 * metrics.inset);
            }
        }
    }

    function test_the_zone_under_the_pointer() {
        const a = Layouts.arrange(Layouts.presets(false), 16 / 9, metrics);
        a.cards.forEach((card, i) => card.zones.forEach((z, j) => {
            compare(Layouts.hit(a, z.x + z.width / 2, z.y + z.height / 2, metrics.inset),
                    { layout: i, zone: j });
        }));
    }

    // Between two zones of a card is still that card: the pointer never
    // falls through a gap it cannot see. Between two cards is nothing.
    function test_gaps_inside_a_card_are_not_gaps() {
        const a = Layouts.arrange(Layouts.presets(false), 16 / 9, metrics);
        const halves = a.cards[0];
        const between = halves.zones[0].x + halves.zones[0].width + metrics.inset - 1;
        verify(Layouts.hit(a, between, halves.y + 20, metrics.inset) !== null);
        compare(Layouts.hit(a, halves.x + halves.width + metrics.gapX / 2, halves.y + 20, metrics.inset), null);
        compare(Layouts.hit(a, -5, -5, metrics.inset), null);
    }

    function test_a_zone_in_the_screens_pixels() {
        const zone = Layouts.presets(false)[1].zones[1];
        compare(Layouts.place(zone, { x: 1920, y: 40, width: 2560, height: 1400 }),
                { x: 1920 + 1707, y: 40, width: 853, height: 1400 });
    }

    function test_the_same_hit() {
        verify(Layouts.sameHit(null, null));
        verify(Layouts.sameHit({ layout: 1, zone: 2 }, { layout: 1, zone: 2 }));
        verify(!Layouts.sameHit({ layout: 1, zone: 2 }, null));
        verify(!Layouts.sameHit({ layout: 1, zone: 2 }, { layout: 1, zone: 0 }));
    }

    // ---- the keyboard ------------------------------------------------------

    function arrangement() {
        return Layouts.arrange(Layouts.presets(false), 16 / 9, metrics);
    }

    function test_every_zone_listed_card_by_card() {
        const list = Layouts.zoneList(arrangement());
        compare(list.length, 2 + 2 + 3 + 3 + 4 + 3);
        compare(list.slice(0, 3).map(z => [z.layout, z.zone]), [[0, 0], [0, 1], [1, 0]]);
        compare(list[2].rect, arrangement().cards[1].zones[0]);
    }

    // Where an arrow goes from { layout, zone }, as { layout, zone }.
    function step(from, direction) {
        const list = Layouts.zoneList(arrangement());
        const at = list.findIndex(z => z.layout === from[0] && z.zone === from[1]);
        const to = list[Layouts.nearest(list.map(z => z.rect), at, direction)];
        return [to.layout, to.zone];
    }

    // Across cards as they lie on the panel, and within one: right from the
    // right half is the next card's first zone, down from a half is the card
    // below it, up and down move between a quarter and the one under it, and
    // up from the top-right quarter is the narrow third above it.
    function test_arrows_move_between_zones_as_they_lie() {
        compare(step([0, 0], "right"), [0, 1]);
        compare(step([0, 1], "right"), [1, 0]);
        compare(step([1, 0], "left"), [0, 1]);
        compare(step([0, 0], "down"), [3, 0]);
        compare(step([4, 0], "down"), [4, 1]);
        compare(step([4, 1], "up"), [4, 0]);
        compare(step([4, 2], "up"), [1, 1]);
    }

    // Right from the top of a stack goes to the top of the card beside it,
    // not to its middle: a step to the side costs more than one along.
    function test_the_arrow_keeps_to_its_row() {
        compare(step([3, 1], "right"), [4, 0]);
        compare(step([3, 2], "right"), [4, 1]);
    }

    function test_nothing_that_way_stays_put() {
        compare(step([0, 0], "left"), [0, 0]);
        compare(step([0, 0], "up"), [0, 0]);
        compare(step([5, 2], "right"), [5, 2]);
        compare(Layouts.nearest([], -1, "left"), -1);
        compare(Layouts.nearest([{ x: 0, y: 0, width: 1, height: 1 }], 0, "sideways"), 0);
    }

    // ---- Snap Assist's grid ------------------------------------------------

    readonly property var assist: ({ cell: 300, gap: 18, pad: 28, label: 28, aspect: 16 / 10 })

    // What the rig's scenario clicks: two windows offered for the right half
    // of a 1920x1080 screen are a column of two, centred in it.
    function test_two_windows_in_a_half() {
        const g = Layouts.grid(2, { x: 960, y: 0, width: 960, height: 1080 }, assist);
        compare(g.columns, 1);
        compare(g.cells, [{ x: 1290, y: 315, width: 300, height: 216 },
                          { x: 1290, y: 549, width: 300, height: 216 }]);
    }

    // However many there are, the cells are one size, no wider than the
    // most a cell may be, inside the zone and its padding, and apart.
    function test_cells_fit_the_zone() {
        const boxes = [{ x: 960, y: 0, width: 960, height: 1080 }, { x: 640, y: 0, width: 640, height: 1080 },
                       { x: 0, y: 540, width: 960, height: 540 }, { x: 0, y: 0, width: 1080, height: 960 }];
        for (const box of boxes) {
            for (let n = 1; n <= 12; ++n) {
                const cells = Layouts.grid(n, box, assist).cells;
                const what = `${n} in ${JSON.stringify(box)}`;
                compare(cells.length, n, what);
                for (const c of cells) {
                    compare([c.width, c.height], [cells[0].width, cells[0].height], what);
                    verify(c.width <= assist.cell, what);
                    compare(c.height, Math.round(c.width / assist.aspect) + assist.label, what);
                    verify(c.x >= box.x + assist.pad - 1 && c.x + c.width <= box.x + box.width - assist.pad + 1, what);
                    verify(c.y >= box.y + assist.pad - 1 && c.y + c.height <= box.y + box.height - assist.pad + 1, what);
                }
                for (let i = 0; i < n; ++i)
                    for (let j = i + 1; j < n; ++j)
                        verify(!overlap(cells[i], cells[j]), `${what}: cells ${i} and ${j} overlap`);
            }
        }
    }

    // Five in a half are two columns of three rows, the last row's one cell
    // in the middle rather than on the left.
    function test_a_short_last_row_is_centred() {
        const box = { x: 0, y: 0, width: 960, height: 1080 };
        const g = Layouts.grid(5, box, assist);
        compare(g.columns, 2);
        const last = g.cells[4];
        compare(last.x + last.width / 2, box.width / 2);
    }

    function test_nothing_offered_is_no_grid() {
        compare(Layouts.grid(0, { x: 0, y: 0, width: 960, height: 1080 }, assist), { columns: 0, cells: [] });
    }

    function test_a_window_at_a_zones_place() {
        const zone = { x: 960, y: 0, width: 960, height: 1080 };
        verify(Layouts.matches({ x: 961, y: 1, width: 958, height: 1079 }, zone, 2));
        verify(!Layouts.matches({ x: 900, y: 0, width: 960, height: 1080 }, zone, 2));
    }

    // ---- KWin's tiles ------------------------------------------------------

    // KWin 6.8's tile takes a window itself; one before it is written to the
    // window. Both ways round, and the windows a tile has, either way.
    function test_a_tile_that_manages_is_asked() {
        const held = [];
        const tile = { manage: w => held.push(w), unmanage: w => held.splice(held.indexOf(w), 1) };
        const w = { tile: null };
        Layouts.manage(tile, w);
        verify(held.length === 1 && held[0] === w);
        compare(w.tile, null);
        Layouts.unmanage(tile, w);
        compare(held.length, 0);
    }

    function test_an_older_tile_is_written_to_the_window() {
        const tile = {};
        const w = { tile: null };
        Layouts.manage(tile, w);
        verify(w.tile === tile);
        Layouts.unmanage(tile, w);
        compare(w.tile, null);
    }

    function test_the_windows_in_a_tile() {
        const a = { tile: null };
        const b = { tile: null };
        const listed = { windows: [a] };
        const found = Layouts.windowsIn(listed, [a, b]);
        verify(found.length === 1 && found[0] === a);
        const older = {};
        b.tile = older;
        const named = Layouts.windowsIn(older, [a, b]);
        verify(named.length === 1 && named[0] === b);
    }

    // ---- KWin's tiles ------------------------------------------------------

    // A tile as KWin's scripting API shows one, splitting as it was measured
    // to. `dir` is KWin's numbering: 1 side by side, 2 one above the other.
    Component {
        id: tileType

        QtObject {
            id: tile

            property var parentTile: null
            property var tiles: []
            property var windows: []
            property int dir: 1
            property var geometry: ({ x: 0, y: 0, width: 1, height: 1 })
            property var relativeGeometry: ({ x: 0, y: 0, width: 1, height: 1 })

            onRelativeGeometryChanged: {
                const g = tile.relativeGeometry;
                const r = { x: g.x, y: g.y, width: g.width, height: g.height };
                const p = tile.parentTile;
                const next = p ? p.tiles[p.tiles.indexOf(tile) + 1] : null;
                tile.geometry = r;
                if (!next)
                    return;
                const n = next.geometry;
                const edge = p.dir === 1 ? r.x + r.width : r.y + r.height;
                next.relativeGeometry = p.dir === 1
                    ? { x: edge, y: n.y, width: n.x + n.width - edge, height: n.height }
                    : { x: n.x, y: edge, width: n.width, height: n.y + n.height - edge };
            }

            function child(r, d) {
                const t = tileType.createObject(null, { parentTile: tile, dir: d, geometry: r });
                t.relativeGeometry = r;
                return t;
            }

            function split(d) {
                const g = tile.geometry;
                const p = tile.parentTile;
                if (p && p.dir === d && tile.tiles.length === 0) {
                    const half = d === 1 ? { x: g.x + g.width / 2, y: g.y, width: g.width / 2, height: g.height }
                                         : { x: g.x, y: g.y + g.height / 2, width: g.width, height: g.height / 2 };
                    tile.geometry = d === 1 ? { x: g.x, y: g.y, width: g.width / 2, height: g.height }
                                            : { x: g.x, y: g.y, width: g.width, height: g.height / 2 };
                    const kids = p.tiles.slice();
                    kids.splice(kids.indexOf(tile) + 1, 0, p.child(half, d));
                    p.tiles = kids;
                    return;
                }
                tile.dir = d;
                const a = d === 1 ? { x: g.x, y: g.y, width: g.width / 2, height: g.height }
                                  : { x: g.x, y: g.y, width: g.width, height: g.height / 2 };
                const b = d === 1 ? { x: g.x + g.width / 2, y: g.y, width: g.width / 2, height: g.height }
                                  : { x: g.x, y: g.y + g.height / 2, width: g.width, height: g.height / 2 };
                tile.tiles = [tile.child(a, d), tile.child(b, d)];
            }

            function remove() {
                const p = tile.parentTile;
                p.tiles = p.tiles.filter(t => t !== tile);
            }
        }
    }

    readonly property var directions: ({ h: 1, v: 2 })

    // KWin's own default: a quarter, a half and a quarter.
    function kwinDefault() {
        const root = tileType.createObject(null);
        root.split(1);
        root.tiles[1].split(1);
        root.tiles[0].relativeGeometry = { x: 0, y: 0, width: 0.25, height: 1 };
        root.tiles[1].relativeGeometry = { x: 0.25, y: 0, width: 0.5, height: 1 };
        return root;
    }

    function preset(id) {
        return Layouts.presets(false).find(p => p.id === id);
    }

    function test_the_stand_in_starts_as_kwin_does() {
        verify(Layouts.sameZones(Layouts.tileZones(kwinDefault()), preset("wideCentre").zones));
    }

    function test_a_screen_with_one_tile_has_no_layout() {
        compare(Layouts.tileZones(tileType.createObject(null)), []);
    }

    function test_tiles_made_into_each_layout() {
        for (const p of Layouts.presets(false).concat(Layouts.presets(true))) {
            const root = kwinDefault();
            verify(Layouts.build(root, p.tree, directions), p.id);
            verify(Layouts.sameZones(Layouts.tileZones(root), p.zones), `${p.id}: ${JSON.stringify(Layouts.tileZones(root))}`);
            for (const z of p.zones)
                verify(Layouts.leafFor(root, z) !== null, `${p.id}: a tile for ${JSON.stringify(z)}`);
        }
    }

    // Snapping into the layout the tiles already make keeps them, and the
    // windows in them: the second window of a pair joins the first.
    function test_the_layout_already_there_is_kept() {
        const root = kwinDefault();
        Layouts.build(root, preset("halves").tree, directions);
        const left = Layouts.leafFor(root, preset("halves").zones[0]);
        verify(Layouts.build(root, preset("halves").tree, directions));
        verify(Layouts.leafFor(root, preset("halves").zones[0]) === left);
    }

    // Another layout lets the windows in the old one go, where they are --
    // KWin would hand them to the whole screen.
    function test_another_layout_leaves_windows_where_they_were() {
        const root = kwinDefault();
        Layouts.build(root, preset("halves").tree, directions);
        const w = { tile: null, frameGeometry: { x: 0, y: 0, width: 960, height: 1080 } };
        const left = Layouts.leafFor(root, preset("halves").zones[0]);
        w.tile = left;
        left.windows = [w];
        Layouts.build(root, preset("thirds").tree, directions);
        compare(w.tile, null);
        compare(w.frameGeometry.width, 960);
    }
}
