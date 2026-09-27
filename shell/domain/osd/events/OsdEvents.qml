pragma Singleton

// Turns one line of `busctl --json=short monitor` into an OSD event.
//
// Kept apart from the service that reads the bus so it can be tested without
// one: this is the part that is easy to get subtly wrong -- a payload arriving
// in a different order, a member we do not handle, a line that is not a signal
// at all -- and the part whose failure looks like "the OSD sometimes does not
// appear".
//
// plasmashell emits these as ordinary signals on org.kde.osdService, so
// drawing our own OSD needs no daemon takeover and no name ownership. We are a
// listener, and Plasma remains the thing that decides an OSD is warranted.
//
// It sits in a module of its own, with no Quickshell import anywhere in it,
// because that is what makes it loadable by qmltestrunner. A module containing
// one singleton that needs the Quickshell runtime cannot be imported at all
// outside a running shell, and the pure function in it becomes untestable by
// association.

import QtQuick
import qs.core

QtObject {
    id: root

    // The two signals that carry everything Plasma's own OSD draws. The rest
    // of the interface -- brightnessChanged, kbdLayoutChanged and the others --
    // are methods plasmashell calls on itself, and they end up here as one of
    // these two.
    readonly property var handled: ["osdProgress", "osdText"]

    // Returns { icon, text, value, maxValue, showingProgress } or null.
    //
    // Null for anything unrecognised rather than a half-filled event: an OSD
    // showing an empty bar because a payload was one element short is worse
    // than one that does not appear.
    function parse(line) {
        // Bounded before it is parsed, like every line off the bus. Plasma's
        // OSD signals are strings and numbers today, so nothing here is
        // expected to be large -- but "expected" is exactly what was assumed
        // about notification hints, and that took the shell down five times.
        const msg = BusLine.parse(line);
        if (!BusLine.isSignal(msg, "org.kde.osdService"))
            return null;

        const data = BusLine.payload(msg);
        if (!data)
            return null;

        if (msg.member === "osdProgress") {
            if (data.length < 3)
                return null;
            const max = Number(data[2]);
            return {
                icon: String(data[0] ?? ""),
                text: String(data[3] ?? ""),
                value: Number(data[1]),
                // A maximum of zero would divide by zero in every bar that
                // draws it, and has been seen on the bus.
                maxValue: max > 0 ? max : 100,
                showingProgress: true
            };
        }

        if (msg.member === "osdText") {
            if (data.length < 2)
                return null;
            return {
                icon: String(data[0] ?? ""),
                text: String(data[1] ?? ""),
                value: 0,
                maxValue: 100,
                showingProgress: false
            };
        }

        return null;
    }

    // ---- events this shell raises itself ---------------------------------
    //
    // plasmashell is not the only thing that knows a volume moved, and on a
    // desktop where it emits nothing (measured on 2026-09-16: the method call
    // arrives, no signal follows) a listener draws nothing for ever. The shell
    // already reads PipeWire and powerdevil for its panel widgets, so these
    // turn a value it already has into the same event shape `parse` returns.
    //
    // Pure, and icon names come from the caller: StatusIcons owns the
    // thresholds, and duplicating them here to keep this module importable by
    // qmltestrunner would put the same rule in two places.

    // A level with a bar: volume, brightness, anything measurable.
    function progress(icon, percent, text) {
        const value = Number(percent);
        if (!isFinite(value))
            return null;
        return {
            icon: String(icon ?? ""),
            text: String(text ?? ""),
            value: Math.max(0, Math.min(100, Math.round(value))),
            maxValue: 100,
            showingProgress: true
        };
    }

    // Words with no bar: muted, a layout name, a toggle.
    function message(icon, text) {
        const words = String(text ?? "");
        if (words.length === 0)
            return null;
        return {
            icon: String(icon ?? ""),
            text: words,
            value: 0,
            maxValue: 100,
            showingProgress: false
        };
    }
}
