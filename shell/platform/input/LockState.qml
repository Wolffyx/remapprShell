// Caps Lock and Num Lock, as they are right now.
//
// Reached through a Loader by file name rather than imported, the same way
// HeldModifiers and StreamSurface are: `ShellInput` is part of this project's
// optional compiled module (plugin/), and a missing QML module is a load
// error for the whole file that imports it. Through a Loader it is an error
// on the Loader, which the caller can see and carry on without -- no OSD for
// the lock keys, and everything else unaffected.
//
// Why this is compiled at all rather than read from QML: nothing on this
// desktop announces a lock key. Plasma shows no OSD for one, and over ninety
// seconds of pressing Caps Lock and Num Lock, `org.kde.osdService` carried
// not one message -- measured 2026-09-16. See plugin/src/lockkeys.h.

// The module is compiled, so qmllint cannot resolve it and reads every
// property it provides as unqualified access -- the same false positive
// HeldModifiers.qml carries next door.
// qmllint disable unqualified
import QtQuick
import ShellInput

QtObject {
    readonly property bool capsLock: LockKeys.capsLock
    readonly property bool numLock: LockKeys.numLock
}
