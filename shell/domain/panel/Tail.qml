pragma Singleton

// The neck a popout hangs from its widget by: the arithmetic, on its own.
//
// A hover card that floats a gap clear of the panel reads as a card *near* a
// button rather than one *of* it -- the taskbar's preview, over a row of
// icons, left the eye to work out which one it belonged to, and the strip of
// wallpaper between the two was reported as dead space (2026-09-24). So the
// card's edge facing the panel flows, through two concave curves, into a neck
// about as wide as the button's tile, which crosses the gap and meets the
// panel's edge on the button's middle: card and button, one shape.
//
// Named for the panel, as Placement is, so one set of rules covers all four
// edges:
//
//   along   the length of the panel, measured on the card from its leading
//           edge (its left on a top or bottom panel, its top on a side one)
//   depth   from the card's far edge towards the panel; the card's near edge
//           is at its thickness, and the panel's edge `span` beyond that
//
// Pure functions, tested in tests/tst_Tail.qml. WidgetSlot draws what they
// describe, and gives the same shape to the compositor as the input region
// and the blur, so what takes the pointer is exactly what is drawn.

import QtQuick

QtObject {
    id: root

    // How far each concave curve reaches along the card from the neck: twice
    // as far as the neck is long, so across the default 12 px gap the card's
    // edge leaves level and turns down gently into the neck -- a drop, where
    // a curve as long as it is wide read as a corner cut out. No further than
    // 28 px when a shadow has opened the gap up: a wide flare over a long
    // neck is a funnel.
    function flare(span) {
        return Math.max(0, Math.min(28, Math.round(2 * span)));
    }

    // Where the neck goes on a card `length` long along the panel, whose
    // corners are `radius` round: centred on `at`, `width` wide where it meets
    // the panel, crossing `span`.
    //
    // It lands on `at` wherever that is on the card, so a card pushed back on
    // screen at the end of the panel still hangs from the button that opened
    // it; only a point past the card's own ends is brought back onto it. Where
    // the neck comes too close to a corner for the corner and the curve both,
    // the two give way together, in proportion, down to a neck that simply
    // continues the card's side -- never a curve drawn over a corner.
    function neck(length, radius, at, width, span) {
        const w = Math.max(0, Math.min(width, length));
        const c = Math.max(w / 2, Math.min(at, length - w / 2));
        const f = root.flare(span);
        const side = room => {
            const want = radius + f;
            const k = want > 0 && room < want ? Math.max(0, room) / want : 1;
            return { flare: f * k, radius: radius * k };
        };
        return {
            at: c,
            width: w,
            span: Math.max(0, span),
            radius: radius,
            lead: side(c - w / 2),
            trail: side(length - c - w / 2)
        };
    }

    // A point given along and depth, on a card `w` x `h`, in the card's own
    // coordinates. The panel's side of the card is where depth runs out.
    function _map(edge, w, h, along, depth) {
        switch (edge) {
        case "top":
            return { x: along, y: h - depth };
        case "left":
            return { x: w - depth, y: along };
        case "right":
            return { x: depth, y: along };
        default:
            return { x: along, y: depth };
        }
    }

    // A box given as two corners along and in depth, mapped the same way.
    function _box(edge, w, h, a0, d0, a1, d1, ox, oy) {
        const p = root._map(edge, w, h, a0, d0);
        const q = root._map(edge, w, h, a1, d1);
        return {
            x: Math.min(p.x, q.x) + (ox ?? 0),
            y: Math.min(p.y, q.y) + (oy ?? 0),
            width: Math.abs(q.x - p.x),
            height: Math.abs(q.y - p.y)
        };
    }

    function _horizontal(edge) {
        return edge !== "left" && edge !== "right";
    }

    // The rectangle the neck and its two curves occupy beyond the card's near
    // edge, in the card's coordinates plus (`ox`, `oy`).
    function box(n, w, h, edge, ox, oy) {
        const length = root._horizontal(edge) ? w : h;
        const thick = root._horizontal(edge) ? h : w;
        const a0 = n.at - n.width / 2 - n.lead.flare;
        const a1 = n.at + n.width / 2 + n.trail.flare;
        return root._box(edge, w, h, Math.max(0, a0), thick, Math.min(length, a1), thick + n.span, ox, oy);
    }

    // The two ellipses the curves are quarters of -- what is cut out of that
    // rectangle to leave the neck. Each is centred where its curve's tangents
    // cross, on the panel's edge, and is empty when its curve has given way.
    function hollows(n, w, h, edge, ox, oy) {
        const thick = root._horizontal(edge) ? h : w;
        const lead = n.at - n.width / 2;
        const trail = n.at + n.width / 2;
        return [
            root._box(edge, w, h, lead - 2 * n.lead.flare, thick, lead, thick + 2 * n.span, ox, oy),
            root._box(edge, w, h, trail, thick, trail + 2 * n.trail.flare, thick + 2 * n.span, ox, oy)
        ];
    }

    // The radius of each of the card's corners: the two on the panel's side
    // as the neck left them, the other two as they were.
    function corners(n, edge) {
        const r = n.radius;
        const out = { topLeft: r, topRight: r, bottomLeft: r, bottomRight: r };
        const near = {
            bottom: ["bottomLeft", "bottomRight"],
            top: ["topLeft", "topRight"],
            left: ["topLeft", "bottomLeft"],
            right: ["topRight", "bottomRight"]
        }[edge] ?? ["bottomLeft", "bottomRight"];
        out[near[0]] = n.lead.radius;
        out[near[1]] = n.trail.radius;
        return out;
    }

    // The card and its neck as one outline, as SVG path data in the card's
    // coordinates: `fill` closed, and `stroke` the same line open across the
    // neck's foot, which rests on the panel's own edge and must not draw a
    // second one there.
    //
    // Drawn half a pixel in from the shape, so a one-pixel stroke covers
    // exactly the pixels a Rectangle's one-pixel border would: the edge of the
    // shape is the edge of the stroke. Every curve is a cubic -- quarter
    // circles for the corners, quarter ellipses for the neck -- so mapping it
    // onto another edge of the screen is only moving its points.
    function outline(n, w, h, edge) {
        const e = 0.5;
        const K = 0.5522847498;
        const horizontal = root._horizontal(edge);
        const L = horizontal ? w : h;
        const T = horizontal ? h : w;
        const s = n.span;
        const foot = T + s;

        const far = Math.max(0, n.radius - e);
        const rl = Math.max(0, n.lead.radius - e);
        const rt = Math.max(0, n.trail.radius - e);
        const fl = n.lead.flare;
        const ft = n.trail.flare;
        const nl = n.at - n.width / 2;
        const nt = n.at + n.width / 2;
        // Where each curve leaves the card's near edge, never inside a corner.
        const ul = Math.max(nl - fl, e + rl);
        const ut = Math.min(nt + ft, L - e - rt);

        const pt = (a, d) => {
            const p = root._map(edge, w, h, a, d);
            return `${+p.x.toFixed(3)} ${+p.y.toFixed(3)}`;
        };
        const line = (a, d) => `L ${pt(a, d)}`;
        const curve = (a1, d1, a2, d2, a, d) => `C ${pt(a1, d1)} ${pt(a2, d2)} ${pt(a, d)}`;

        const parts = [
            `M ${pt(nl + e, foot)}`,
            // Up the leading curve: a quarter ellipse whose tangent is the
            // panel's normal at the foot and the card's edge at the top.
            curve(nl + e, foot - K * (s + e), ul + K * (nl + e - ul), T - e, ul, T - e),
            line(e + rl, T - e),
            curve(e + rl - K * rl, T - e, e, T - e - rl + K * rl, e, T - e - rl),
            line(e, e + far),
            curve(e, e + far - K * far, e + far - K * far, e, e + far, e),
            line(L - e - far, e),
            curve(L - e - far + K * far, e, L - e, e + far - K * far, L - e, e + far),
            line(L - e, T - e - rt),
            curve(L - e, T - e - rt + K * rt, L - e - rt + K * rt, T - e, L - e - rt, T - e),
            line(ut, T - e),
            // Down the trailing curve to the foot.
            curve(ut - K * (ut - (nt - e)), T - e, nt - e, foot - K * (s + e), nt - e, foot)
        ];
        const stroke = parts.join(" ");
        return { stroke: stroke, fill: `${stroke} Z` };
    }
}
