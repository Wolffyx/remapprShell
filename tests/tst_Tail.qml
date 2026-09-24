// The neck a popout hangs from its widget by.
//
// What these hold is where it lands and what gives way when it cannot have
// everything: a neck that missed its button, or a curve drawn across a
// corner, is a number before it is a picture.

import QtQuick
import QtTest
import qs.domain.panel

TestCase {
    name: "Tail"

    // This machine's panel: popouts 12 px clear of it, no shadow, rounding 8,
    // and a taskbar tile 48 px wide whose neck is three quarters of it.
    readonly property int span: 12
    readonly property int radius: 8
    readonly property int neckWidth: 36

    function near(actual, expected, what) {
        verify(Math.abs(actual - expected) < 0.001, `${what}: ${actual}, expected ${expected}`);
    }

    // ---- where it lands ---------------------------------------------------

    function test_centred_on_its_button_with_room_either_side() {
        const n = Tail.neck(400, radius, 200, neckWidth, span);
        compare(n.at, 200);
        compare(n.width, neckWidth);
        compare(n.lead.flare, Tail.flare(span));
        compare(n.trail.flare, Tail.flare(span));
        compare(n.lead.radius, radius);
        compare(n.trail.radius, radius);
    }

    // A card pushed back on screen at the end of the panel is not centred on
    // its button any more. The neck still is.
    function test_a_card_held_at_the_screen_edge_still_hangs_from_its_button() {
        const n = Tail.neck(476, radius, 158, neckWidth, span);
        compare(n.at, 158);
    }

    // Only a point off the card altogether is brought back onto it: a neck
    // hanging beside the card would be attached to nothing.
    function test_never_beside_the_card() {
        compare(Tail.neck(400, radius, -50, neckWidth, span).at, neckWidth / 2);
        compare(Tail.neck(400, radius, 1000, neckWidth, span).at, 400 - neckWidth / 2);
    }

    function test_never_wider_than_the_card() {
        const n = Tail.neck(20, 4, 10, neckWidth, span);
        compare(n.width, 20);
        compare(n.at, 10);
    }

    // ---- what gives way ---------------------------------------------------

    // Close to a corner there is not room for the corner and the curve both.
    // They shrink together, so the edge still turns the corner and then
    // flows into the neck, with no curve drawn over the corner.
    function test_near_a_corner_the_corner_and_the_curve_give_way_together() {
        const f = Tail.flare(span);
        const room = 16;
        const n = Tail.neck(400, radius, room + neckWidth / 2, neckWidth, span);
        near(n.lead.radius + n.lead.flare, room, "they fill the room there is");
        near(n.lead.radius / n.lead.flare, radius / f, "in proportion");
        // The far side had room and keeps everything.
        compare(n.trail.radius, radius);
        compare(n.trail.flare, f);
    }

    // At the very end the neck simply continues the card's side.
    function test_flush_with_the_end_there_is_no_corner_and_no_curve() {
        const n = Tail.neck(400, radius, neckWidth / 2, neckWidth, span);
        compare(n.lead.radius, 0);
        compare(n.lead.flare, 0);
    }

    // ---- its proportions --------------------------------------------------

    // Twice as long as the gap it crosses: the card's edge leaves level and
    // turns down gently. Capped, so a gap opened up for a shadow does not
    // make a funnel of it.
    function test_the_curve_follows_the_gap_up_to_a_point() {
        compare(Tail.flare(12), 24);
        compare(Tail.flare(29), 28);
        compare(Tail.flare(0), 0);
    }

    // ---- on every edge ----------------------------------------------------

    // The rectangle the neck occupies is beyond the card's edge facing the
    // panel, the gap deep, and centred on where it lands.
    function test_the_neck_is_on_the_panels_side_of_the_card() {
        const n = Tail.neck(300, radius, 100, neckWidth, span);
        const reach = n.width / 2 + n.lead.flare;

        const b = Tail.box(n, 300, 200, "bottom", 0, 0);
        near(b.y, 200, "bottom: from the card's bottom edge");
        near(b.height, span, "bottom: the gap deep");
        near(b.x, 100 - reach, "bottom: centred on it");

        const t = Tail.box(n, 300, 200, "top", 0, 0);
        near(t.y, -span, "top: above the card");
        near(t.height, span, "top: the gap deep");
        near(t.x, 100 - reach, "top: centred on it");

        const l = Tail.box(n, 200, 300, "left", 0, 0);
        near(l.x, -span, "left: beside the card");
        near(l.width, span, "left: the gap deep");
        near(l.y, 100 - reach, "left: along the panel, down the screen");

        const r = Tail.box(n, 200, 300, "right", 0, 0);
        near(r.x, 200, "right: from the card's right edge");
        near(r.y, 100 - reach, "right: along the panel");
    }

    // Given in the window's coordinates, for the input region and the blur.
    function test_the_box_moves_with_the_card() {
        const n = Tail.neck(300, radius, 100, neckWidth, span);
        const a = Tail.box(n, 300, 200, "bottom", 0, 0);
        const b = Tail.box(n, 300, 200, "bottom", 29, 7);
        near(b.x - a.x, 29, "x");
        near(b.y - a.y, 7, "y");
    }

    // What is cut out to leave the neck: ellipses centred on the panel's edge
    // at the neck's sides, as wide as the curves reach. None where a curve
    // has given way.
    function test_the_hollows_are_the_curves() {
        const n = Tail.neck(300, radius, 100, neckWidth, span);
        const [lead, trail] = Tail.hollows(n, 300, 200, "bottom", 0, 0);
        near(lead.x + lead.width / 2, 100 - neckWidth / 2 - n.lead.flare, "lead centre along");
        near(lead.y + lead.height / 2, 200 + span, "lead centre on the panel's edge");
        near(lead.width, 2 * n.lead.flare, "lead as wide as its curve reaches");
        near(trail.x + trail.width / 2, 100 + neckWidth / 2 + n.trail.flare, "trail centre along");

        const flush = Tail.neck(300, radius, neckWidth / 2, neckWidth, span);
        compare(Tail.hollows(flush, 300, 200, "bottom", 0, 0)[0].width, 0);
    }

    // The corners beside the neck are as round as it left them; the other two
    // are the card's.
    function test_the_corners_on_the_panels_side_are_the_necks() {
        const n = Tail.neck(400, radius, 16 + neckWidth / 2, neckWidth, span);
        const c = Tail.corners(n, "bottom");
        near(c.bottomLeft, n.lead.radius, "bottom left");
        near(c.bottomRight, radius, "bottom right");
        near(c.topLeft, radius, "top left");
        near(c.topRight, radius, "top right");

        compare(Tail.corners(n, "top").topLeft, n.lead.radius);
        compare(Tail.corners(n, "left").topLeft, n.lead.radius);
        compare(Tail.corners(n, "left").bottomLeft, radius);
        compare(Tail.corners(n, "right").topRight, n.lead.radius);
    }

    // ---- the outline ------------------------------------------------------

    function points(path) {
        const nums = path.match(/-?\d+(\.\d+)?/g).map(Number);
        const out = [];
        for (let i = 0; i + 1 < nums.length; i += 2)
            out.push({ x: nums[i], y: nums[i + 1] });
        return out;
    }

    // Closed for the fill; open across the neck's foot for the border, which
    // rests on the panel's own edge -- a border there would be a second line
    // on top of the panel's.
    function test_the_border_is_open_where_the_neck_meets_the_panel() {
        const n = Tail.neck(300, radius, 100, neckWidth, span);
        const o = Tail.outline(n, 300, 200, "bottom");
        verify(o.fill.trim().endsWith("Z"));
        verify(!o.stroke.includes("Z"));
        const p = points(o.stroke);
        const first = p[0];
        const last = p[p.length - 1];
        near(first.y, 200 + span, "it starts on the panel's edge");
        near(last.y, 200 + span, "and ends there");
        near(first.x, 100 - neckWidth / 2 + 0.5, "at the neck's leading side");
        near(last.x, 100 + neckWidth / 2 - 0.5, "and its trailing side");
    }

    // The same shape on every edge: the foot of the neck is always on the
    // panel's side, and nothing is drawn beyond the card and the gap.
    function test_every_edge_ends_on_the_panel() {
        const n = Tail.neck(300, radius, 100, neckWidth, span);
        const cases = [
            { edge: "bottom", w: 300, h: 200, foot: p => p.y === 200 + span, inside: p => p.x >= 0 && p.x <= 300 && p.y >= 0 && p.y <= 200 + span },
            { edge: "top", w: 300, h: 200, foot: p => p.y === -span, inside: p => p.x >= 0 && p.x <= 300 && p.y >= -span && p.y <= 200 },
            { edge: "left", w: 200, h: 300, foot: p => p.x === -span, inside: p => p.y >= 0 && p.y <= 300 && p.x >= -span && p.x <= 200 },
            { edge: "right", w: 200, h: 300, foot: p => p.x === 200 + span, inside: p => p.y >= 0 && p.y <= 300 && p.x >= 0 && p.x <= 200 + span }
        ];
        for (const c of cases) {
            const p = points(Tail.outline(n, c.w, c.h, c.edge).stroke);
            verify(c.foot(p[0]), `${c.edge}: starts on the panel's edge`);
            verify(c.foot(p[p.length - 1]), `${c.edge}: ends on the panel's edge`);
            verify(p.every(c.inside), `${c.edge}: drawn inside the card and the gap`);
        }
    }

    // Half a pixel in from the card's own edges, so a one-pixel border covers
    // exactly the pixels a Rectangle's border would.
    function test_the_border_is_drawn_on_the_cards_own_pixels() {
        const n = Tail.neck(300, radius, 150, neckWidth, span);
        const p = points(Tail.outline(n, 300, 200, "bottom").stroke);
        const xs = p.map(q => q.x);
        const ys = p.filter(q => q.y < 200).map(q => q.y);
        near(Math.min(...xs), 0.5, "left edge");
        near(Math.max(...xs), 299.5, "right edge");
        near(Math.min(...ys), 0.5, "top edge");
    }
}
