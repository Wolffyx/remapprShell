/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The on-screen keyboard, whichever Plasma 6 this is.

    Breeze's VirtualKeyboardLoader drew it until Plasma 6.8 took it out. The
    frame named that loader as a type, so on 6.8 the greeter refused the whole
    lock screen and drew its built-in locker (2026-10-16). Nothing here names
    a type a Plasma release could take away: what it uses is looked for at run
    time, and what is missing costs only the keyboard button.

    - Wayland, every release: KWin's keyboard, through Plasma's
      `KWinVirtualKeyboard` (LockKeys.kwinKeyboard). Plasma 6.8 shows it with
      `forceActivate()` and hides it by deactivating it; before 6.8 there was
      no `forceActivate()`, and the lock screen asked through Qt's input
      method instead. Which one this greeter has is asked of the object, not
      of a version number.
    - X11 (Plasma 6.7 and before): Qt's own keyboard, drawn in this window by
      LockX11Keyboard, made only here and only then.

    KWin draws its keyboard over the screen itself, and Plasma 6.8's lock
    screen does not move for it; neither does this. Qt's keyboard on X11 is
    drawn in this window, so its height is known, and the style is lifted out
    of its way by as much as it covers below the prompt and no more.
*/
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: board

    // How far down, in this item's coordinates, the style must stay visible.
    required property real visibleBoundary

    readonly property bool x11: Qt.platform.pluginName === "xcb"

    // One of the two, or neither where it could not be had.
    readonly property var kwin: board.x11 ? null : LockKeys.kwinKeyboard
    readonly property var panel: board.x11 ? board.makePanel() : null

    readonly property bool available: board.kwin !== null || board.panel !== null
    readonly property bool shown: board.panel ? board.panel.active : (board.kwin?.visible ?? false)

    // How far the style moves up for the keyboard: zero or less.
    readonly property real lift: board.panel?.active
        ? Math.min(0, board.height - board.panel.height - board.visibleBoundary)
        : 0

    function toggle(): void {
        if (board.panel) {
            board.panel.toggle();
            return;
        }
        if (board.kwin)
            board.toggleKwin(board.kwin);
    }

    function toggleKwin(kwin: var): void {
        const canForce = typeof kwin.forceActivate === "function";
        if (kwin.visible && canForce) {
            kwin.active = false;
            return;
        }
        if (kwin.visible) {
            InputMethod.hide();
            return;
        }
        if (canForce) {
            kwin.forceActivate();
            return;
        }
        InputMethod.show();
    }

    // Qt's keyboard, made from its own file so that this one never names it:
    // where Qt's keyboard module is not installed, that file does not load,
    // and the lock screen goes without the button rather than without itself.
    function makePanel(): var {
        const component = Qt.createComponent(Qt.resolvedUrl("LockX11Keyboard.qml"));
        if (component.status !== Component.Ready) {
            console.warn(`lock screen: no on-screen keyboard: ${component.errorString()}`);
            return null;
        }
        return component.createObject(board);
    }
}
