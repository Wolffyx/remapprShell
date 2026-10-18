/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The window that takes clicks and keys: the panel of layouts opened by
    Meta+Z, and Snap Assist after a window has been snapped. Picker.qml puts
    what it shows inside it and does everything a click or a key means; this
    only passes them on.

    The drag's own panel can be a window KWin only draws, since KWin holds
    the pointer for the whole drag. This one cannot, and how it is made is
    what was measured in the rig on KWin 6.8:

    - Qt.Popup. KWin gives a popup of its own the keyboard while it is up and
      leaves the window that was active as it was, so a key after it goes
      back to that window. A window KWin manages instead (no flag) is placed
      by KWin's placement and loses focus at once; one it bypasses
      (Qt.BypassWindowManagerHint, as the drag's) gets clicks and no keys.
    - A popup is cancelled by KWin when a click lands outside it -- on a
      panel outside the area this covers. Inside it, a click on nothing
      chosen is ours to answer, and dismisses it the same way.
    - It is put away with close(), as KWin's own cancelling does, and not by
      hiding it: that drops the window KWin made for it, and the next one is
      new. A hidden one still said it was active, and was shown again
      believing it.
*/
import QtQuick
import QtQuick.Window as QuickWindow

QuickWindow.Window {
    id: chooser

    // The screen's room for windows, which this covers.
    property rect area

    // A pointer moving or clicking, at x, y in this window, and a key; all
    // of it is Picker.qml's to answer.
    signal pointerMoved(real x, real y)
    signal pointerClicked(real x, real y, int button)
    signal keyPressed(int key)

    // Shown, and given the keyboard -- once. Snap Assist going on to the
    // next zone opens it again while it is up, and asking KWin to activate a
    // popup it had already activated lost it the keyboard: the next key went
    // nowhere (the rig, KWin 6.8).
    function open() {
        if (chooser.visible)
            return;
        chooser.visible = true;
        chooser.requestActivate();
        keyboard.forceActiveFocus();
    }

    flags: Qt.Popup | Qt.FramelessWindowHint
    // Declared inside an Item, a window waits for that item's window; see
    // main.qml's panel.
    transientParent: null
    color: "transparent"
    visible: false

    x: chooser.area.x
    y: chooser.area.y
    width: Math.max(1, chooser.area.width)
    height: Math.max(1, chooser.area.height)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPositionChanged: mouse => chooser.pointerMoved(mouse.x, mouse.y)
        onClicked: mouse => chooser.pointerClicked(mouse.x, mouse.y, mouse.button)
    }

    Item {
        id: keyboard

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            chooser.keyPressed(event.key);
            event.accepted = true;
        }
    }
}
