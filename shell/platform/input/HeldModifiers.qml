// Is a switcher's modifier held right now?
//
// Reached through a Loader by file name rather than imported, the same way
// StreamSurface is: `ShellInput` is part of this project's optional compiled
// module (plugin/), and a missing QML module is a load error for the whole
// file that imports it. Through a Loader it is an error on the Loader, which
// the caller can see and carry on without.
//
// Everything this answers is available to QML only as "the modifiers that came
// with an event". The switcher needs the state at an instant, with no event to
// hang it on -- see plugin/src/modifiers.h for why.

import QtQuick
import ShellInput

QtObject {
    // True while Alt or Meta is down. False is a real answer, not "cannot
    // tell": a caller that cannot load this file never gets here at all.
    function held(): bool {
        return Modifiers.switcherKeyHeld();
    }
}
