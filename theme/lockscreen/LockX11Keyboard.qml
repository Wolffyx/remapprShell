/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Qt's on-screen keyboard, drawn in the greeter's own window: what the lock
    screen offers on X11, where KWin has no keyboard of its own to show. As
    Breeze's VirtualKeyboard.qml drew it until Plasma 6.8, which has no X11
    session and took that file out.

    Made only by LockVirtualKeyboard, only on X11, and at run time: this file
    imports Qt's keyboard module, and a lock screen that named it as a type
    would not load at all where that module is not installed.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.VirtualKeyboard as QtVK
import org.kde.kirigami as Kirigami

QtVK.InputPanel {
    id: panel

    // Asked for with the keyboard button; up only while Qt's input method
    // agrees, so the keyboard's own hide key puts it away too.
    property bool activated: false
    active: panel.activated && InputMethod.visible

    function toggle(): void {
        if (panel.active) {
            panel.activated = false;
            InputMethod.hide();
            return;
        }
        panel.activated = true;
        InputMethod.show();
    }

    width: panel.parent ? panel.parent.width : 0

    states: [
        State {
            name: "visible"
            when: panel.active
            PropertyChanges {
                panel.y: panel.parent.height - panel.height
                panel.opacity: 1
                panel.visible: true
            }
        },
        State {
            name: "hidden"
            when: !panel.active
            PropertyChanges {
                panel.y: panel.parent.height
                panel.opacity: 0
                panel.visible: false
            }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            ParallelAnimation {
                // From the bottom edge every time: the panel reparents
                // itself as it becomes active, and would start from 0.
                YAnimator {
                    from: panel.parent.height
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutQuad
                }
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutQuad
                }
            }
        },
        Transition {
            to: "hidden"
            ParallelAnimation {
                YAnimator {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InQuad
                }
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InQuad
                }
            }
        }
    ]
}
