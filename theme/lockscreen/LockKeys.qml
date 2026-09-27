/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What the keyboard is doing, and what is playing: Caps Lock, the keyboard
    layout, and the media players.

    Plasma's own objects, each made once. The greeter draws one view per
    screen from one QML engine (see PasswordSync), so a singleton is one Caps
    Lock, one list of layouts and one list of players for every screen and
    every part of every style -- where each part used to make its own, and a
    style drawing the warning under its field and the layout in its corner
    held two of each.

    Made at run time from text, not imported. A singleton this directory's
    qmldir names is loaded whenever *any* file here is compiled, whether that
    file uses it or not -- so importing Plasma's modules here made Unlock,
    which is pure logic, need the whole of Plasma to compile, and the
    test that loads it failed in CI, which has none (2026-09-24). Made this
    way, a module that is missing costs only its own part: no Caps Lock
    warning, no layout, no player, and the lock screen itself still loads.
*/
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: keys

    // One of Plasma's objects, or null where its module is not installed.
    function make(source: string): var {
        try {
            return Qt.createQmlObject(source, keys, "LockKeys");
        } catch (e) {
            console.warn(`lock screen: ${e.qmlErrors?.[0]?.message ?? e}`);
            return null;
        }
    }

    // --- Caps Lock --------------------------------------------------------

    readonly property var capsLock: keys.make(
        "import QtQuick; import org.kde.plasma.private.keyboardindicator; KeyState { key: Qt.Key_CapsLock }")

    readonly property bool caps: keys.capsLock?.locked ?? false

    // --- the layout -------------------------------------------------------

    readonly property var keyboardLayout: keys.make(
        "import org.kde.plasma.workspace.keyboardlayout; KeyboardLayout {}")

    // Every layout the person set up, in their order, and the one typed in
    // now -- or null before the list has arrived.
    readonly property var layouts: keys.keyboardLayout?.layoutsList ?? []
    readonly property var current: keys.layouts[keys.keyboardLayout?.layout ?? -1] ?? null
    readonly property string layoutName: keys.current?.longName ?? ""

    // A password typed on the wrong layout is refused as surely as a wrong
    // one, and counts against the account the same. The first layout in the
    // list is the one a person set up as theirs; any other is worth saying.
    readonly property bool otherLayout: keys.layouts.length > 1 && (keys.keyboardLayout?.layout ?? 0) > 0

    function nextLayout(): void {
        if (keys.layouts.length > 1)
            keys.keyboardLayout.switchToNextLayout();
    }

    // --- what is playing --------------------------------------------------

    // The players Plasma's own lock screen would show, which is the module
    // it uses: a player it can control is one these can control too.
    readonly property var players: keys.make("import org.kde.plasma.private.mpris; MultiplexerModel {}")

    component Player: QtObject {
        required property var model
    }

    readonly property Instantiator playerRow: Instantiator {
        model: keys.players
        delegate: Player {}
    }

    // The one player Plasma's lock screen would control, or null.
    readonly property var player: keys.playerRow.count > 0
        ? (keys.playerRow.objectAt(0) as Player)?.model ?? null : null
}
