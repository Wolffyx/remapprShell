pragma Singleton

// One kglobalaccel signal, turned into "which of this shell's actions".
//
// Kept apart from the watcher that reads the bus so it can be tested without
// one, for the reason every parser in this shell is: this is the part whose
// failure looks like "the key sometimes does nothing" -- another component's
// action arriving on the same interface, a payload one element short, a
// repeat event treated as a fresh press.
//
// It sits in a module of its own, with no Quickshell import anywhere in it,
// because that is what makes it loadable by qmltestrunner.

import QtQuick
import qs.core

QtObject {
    id: root

    readonly property string interfaceName: "org.kde.kglobalaccel.Component"

    // A key going down, and coming back up. `globalShortcutRepeated` is
    // deliberately not one of these: a held Alt+Tab repeats, and a repeat is
    // the switcher already being open rather than a second request to open it.
    function kindOf(member) {
        if (member === "globalShortcutPressed")
            return "pressed";
        if (member === "globalShortcutReleased")
            return "released";
        return "";
    }

    // Returns { action, kind } for one of `component`'s shortcuts, or null.
    //
    // Null for anything else, including another component's actions: every
    // shell on the machine registers its keys on this same interface, so the
    // component name is the only thing separating our Meta from somebody
    // else's.
    function parse(line, component) {
        const msg = BusLine.parse(line);
        if (!BusLine.isSignal(msg, root.interfaceName))
            return null;

        const kind = root.kindOf(msg.member);
        if (kind.length === 0)
            return null;

        const data = BusLine.payload(msg, 2);
        if (!data)
            return null;

        if (String(data[0]) !== component)
            return null;

        const action = String(data[1]);
        if (action.length === 0)
            return null;

        return { action: action, kind: kind };
    }

    // kglobalaccel's object path for a component: its unique name with the
    // characters D-Bus will not have in a path replaced, so a hyphenated
    // component name becomes an underscored path.
    function pathFor(component) {
        return "/component/" + String(component).replace(/[-.]/g, "_");
    }
}
