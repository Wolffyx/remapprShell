pragma Singleton

// The title-bar buttons' arithmetic: KWin's letters, the four choices, and
// the moves the custom editor makes, each a plain function of the two sides
// so tests/tst_TitleButtons.qml can check them without a window.
//
// A state is { left: ["X", "I"], right: ["A"], sel: { side, code } | null }:
// each side the letters from its outer edge inwards for the left and from
// the title outwards for the right, which is the order kwinrc writes them in.
// Every move returns a new state and leaves the one it was given alone.
//
// What is written to KWin, and how it is put back, is the CLI's:
// scripts/lib/windows/titlebar.sh, which this mirrors for the fixed sides.

import QtQuick

QtObject {
    id: root

    // KWin's letters, as kwinrc writes them, and what each is.
    readonly property var buttons: ({
        M: { glyph: "menu", name: "Window menu" },
        S: { glyph: "push_pin", name: "On all desktops" },
        H: { glyph: "help", name: "Help" },
        I: { glyph: "remove", name: "Minimise" },
        A: { glyph: "crop_square", name: "Maximise" },
        X: { glyph: "close", name: "Close" },
        F: { glyph: "vertical_align_top", name: "Keep above" },
        B: { glyph: "vertical_align_bottom", name: "Keep below" },
        L: { glyph: "expand_less", name: "Shade" }
    })
    readonly property var order: ["M", "S", "H", "I", "A", "X", "F", "B", "L"]

    readonly property var modes: ["plasma", "right", "left", "custom"]
    readonly property var labels: ["Plasma's", "Right", "Left", "Custom"]
    readonly property var glyphs: ["tune", "east", "west", "drag_indicator"]
    readonly property var hints: ({
        plasma: "KWin's own order, untouched: whatever Plasma's Window Decorations settings say.",
        right: "Minimise, maximise and close at the right, close in the corner.",
        left: "Close, minimise and maximise at the left, close in the corner, the title centred.",
        custom: "Any of KWin's buttons, on either side, in your order."
    })

    // The two choices that are a fixed order. Plasma's is whatever KWin has,
    // and custom is the person's.
    readonly property var fixed: ({
        right: { left: [], right: ["I", "A", "X"] },
        left: { left: ["X", "I", "A"], right: [] }
    })

    // Breeze's, which KWin uses when nothing is set.
    readonly property string breezeLeft: "MS"
    readonly property string breezeRight: "HIAX"

    // "XIA" -> ["X", "I", "A"], keeping KWin's letters only, each once.
    function split(letters) {
        const seen = {};
        return String(letters ?? "").split("").filter(c => {
            if (!root.buttons[c] || seen[c])
                return false;
            seen[c] = true;
            return true;
        });
    }

    function letters(list) {
        return (list ?? []).join("");
    }

    // What a choice shows: the fixed order, the person's own for custom, and
    // for Plasma's what KWin has now.
    function sidesOf(mode, custom, kwin) {
        const f = root.fixed[mode];
        if (f)
            return { left: f.left.slice(), right: f.right.slice() };
        const from = mode === "custom" ? custom : kwin;
        return { left: root.split(from?.left), right: root.split(from?.right) };
    }

    // The buttons on neither side, in KWin's order.
    function pool(state) {
        const used = state.left.concat(state.right);
        return root.order.filter(c => used.indexOf(c) < 0);
    }

    // What the readout says KWin is told.
    function line(mode, sides) {
        if (mode === "plasma")
            return "Nothing written";
        return `ButtonsOnLeft=${root.letters(sides.left)}   ButtonsOnRight=${root.letters(sides.right)}`;
    }

    function _copy(state) {
        return { left: state.left.slice(), right: state.right.slice(), sel: state.sel };
    }

    // Selecting a chip, or the same one again to let go of it.
    function pick(state, side, code) {
        const next = root._copy(state);
        const same = state.sel && state.sel.code === code;
        next.sel = same ? null : { side: side, code: code };
        return next;
    }

    // Towards the left: back along its side, and off the start of the right
    // side onto the end of the left. Nowhere to go at the left edge.
    function moveBack(state) {
        if (!state.sel)
            return state;
        const next = root._copy(state);
        const list = next[next.sel.side];
        const i = list.indexOf(next.sel.code);
        if (i > 0) {
            list.splice(i - 1, 0, list.splice(i, 1)[0]);
            return next;
        }
        if (next.sel.side !== "right")
            return state;
        list.splice(i, 1);
        next.left.push(next.sel.code);
        next.sel = { side: "left", code: next.sel.code };
        return next;
    }

    // Towards the right: on along its side, and off the end of the left side
    // onto the start of the right.
    function moveOn(state) {
        if (!state.sel)
            return state;
        const next = root._copy(state);
        const list = next[next.sel.side];
        const i = list.indexOf(next.sel.code);
        if (i < list.length - 1) {
            list.splice(i + 1, 0, list.splice(i, 1)[0]);
            return next;
        }
        if (next.sel.side !== "left")
            return state;
        list.splice(i, 1);
        next.right.unshift(next.sel.code);
        next.sel = { side: "right", code: next.sel.code };
        return next;
    }

    // To the end of the other side's row: beside the title on the left,
    // in the corner on the right.
    function otherSide(state) {
        if (!state.sel)
            return state;
        const next = root._copy(state);
        const from = next.sel.side;
        const to = from === "left" ? "right" : "left";
        next[from].splice(next[from].indexOf(next.sel.code), 1);
        next[to].push(next.sel.code);
        next.sel = { side: to, code: next.sel.code };
        return next;
    }

    function hide(state) {
        if (!state.sel)
            return state;
        const next = root._copy(state);
        const list = next[next.sel.side];
        list.splice(list.indexOf(next.sel.code), 1);
        next.sel = null;
        return next;
    }

    // A hidden button, onto the far end of the right side -- the outer
    // edge, where a title bar's buttons usually end -- and selected, so the
    // next move is one click.
    function add(state, code) {
        if (!root.buttons[code] || state.left.concat(state.right).indexOf(code) >= 0)
            return state;
        const next = root._copy(state);
        next.right.push(code);
        next.sel = { side: "right", code: code };
        return next;
    }
}
