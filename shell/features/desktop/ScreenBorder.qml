pragma ComponentBehavior: Bound

// A rounded frame around the screen, as the design draws the desktop: the
// picture inset a little and its corners cut.
//
// Cosmetic, and off by default. It reserves nothing and takes no input -- an
// empty mask, so a click at the very edge of the screen still reaches
// whatever is under it, and a maximised window still uses the whole screen.
// What changes is only what is seen: the corners are painted over.
//
// KWin has no rounded-corner effect of its own, so this is the honest way to
// get the look: paint the corners, do not pretend the windows are rounded.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.domain.config
import qs.domain.theme

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property int inset: Math.max(0, ConfigStore.value("desktop.borderInset", 0))
    readonly property int radius: Math.max(0, ConfigStore.value("desktop.borderRadius", 13))

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: 0
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: `${Branding.slug}-border`
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    // One path with a hole in it: the screen, minus the rounded rectangle
    // inside it. Four rectangles and four corner pieces would need the corner
    // pieces to be the *outside* of a curve, which is exactly what an
    // even-odd fill gives for nothing.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Theme.dark ? "#000000" : Theme.surfaceDim
            fillRule: ShapePath.OddEvenFill
            strokeWidth: 0

            PathRectangle {
                x: 0
                y: 0
                width: root.width
                height: root.height
            }

            PathRectangle {
                x: root.inset
                y: root.inset
                width: Math.max(0, root.width - 2 * root.inset)
                height: Math.max(0, root.height - 2 * root.inset)
                radius: root.radius
            }
        }
    }
}
