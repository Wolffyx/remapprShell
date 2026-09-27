pragma ComponentBehavior: Bound

// A button on the taskbar: an application's icon -- or a window's, with its
// title beside it where there is room -- the focused one tinted, and under it
// a mark for each window.
//
// It is drawn at the widget's sizes, worked out once for the whole row, and it
// only draws: clicks and hovers reach the widget from the panel, not the
// button (see Widget.qml), and the widget works out which button they were.

import QtQuick
import qs.domain.theme
import qs.domain.windows.events
import qs.ui.primitives

Rectangle {
    id: button

    // The tasks widget: the sizes this is drawn at, which button the pointer
    // is over, and each button's item.
    required property var taskbar

    // The button's key, and its place on the taskbar.
    required property string modelData
    required property int index
    readonly property var item: button.taskbar.itemFor(button.index, button.modelData)

    readonly property bool isActive: button.item.active === true
    // A group is dimmed only when every window in it is minimised: one visible
    // window means the application is on screen. A pinned application with no
    // windows is not minimised, just not running.
    readonly property bool isMinimized: button.windowCount > 0
                                        && button.item.windows.every(w => w.minimized)
    readonly property bool isHovered: button.index === button.taskbar.hoveredIndex
    readonly property int windowCount: button.item.windows.length

    width: button.taskbar.titlesFit
        ? Math.min(button.taskbar.maxWidth, button.taskbar.share, content.implicitWidth + 2 * button.taskbar.padding)
        : button.taskbar.drawnIconOnly
    height: button.taskbar.buttonHeight
    radius: Math.round(14 * Math.max(0.7, button.taskbar.unit))

    // Buttons sit on the panel itself, as the design draws them: no tile until
    // hovered, and the focused window's in the accent's container colour.
    color: button.isActive  ? Theme.accC
         : button.isHovered ? Theme.s2
                            : "transparent"

    // A minimised window is still there and still clickable; it is dimmed
    // rather than hidden, which is the whole difference between a task list
    // and a window list.
    opacity: button.isMinimized ? 0.55 : 1

    Behavior on color { ColorAnimation { duration: 100 } }

    // A window asking for attention -- a message arrived, a dialog wants an
    // answer -- flashes its button for a few seconds and then keeps an orange
    // tint until it is looked at, as Windows does. KWin clears the request
    // when the window is activated, and the tint goes with it.
    //
    // The moment the request began is kept by WindowsService, not here: a
    // button is made again whenever its window leaves the list and comes back
    // -- to another desktop and back, or the grouping switched -- and a flash
    // timed from the button would start over each time.
    readonly property bool wantsAttention: button.item.attention === true && !button.isActive
    property bool flashing: false

    function startFlash() {
        const left = button.taskbar.flashMs - (Date.now() - (button.item.attentionSince ?? 0));
        button.flashing = button.wantsAttention && left > 0;
        if (button.flashing) {
            flashStop.interval = left;
            flashStop.restart();
        }
    }

    onWantsAttentionChanged: button.startFlash()
    Component.onCompleted: button.startFlash()

    Timer {
        id: flashStop
        onTriggered: button.flashing = false
    }

    Rectangle {
        id: attentionTint
        anchors.fill: parent
        radius: parent.radius
        color: Theme.neutral
        visible: button.wantsAttention
        opacity: 0.45

        SequentialAnimation on opacity {
            running: button.flashing
            loops: Animation.Infinite
            NumberAnimation { to: 0.9; duration: 420; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0.15; duration: 420; easing.type: Easing.InOutQuad }
        }
    }

    onFlashingChanged: if (!button.flashing) attentionTint.opacity = 0.45

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Math.round(10 * Math.max(0.7, button.taskbar.unit))

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: button.taskbar.drawnIcon
            height: button.taskbar.drawnIcon

            // Several windows: a square behind the icon, up and to the right,
            // as if a second copy of the application were stacked under the
            // first -- the count read at a glance on the button itself, not
            // only in the marks under it.
            Rectangle {
                visible: button.taskbar.stackGroups && button.windowCount > 1
                width: Math.round(button.taskbar.drawnIcon * 0.86)
                height: width
                x: Math.round(button.taskbar.drawnIcon * 0.26)
                y: -Math.round(button.taskbar.drawnIcon * 0.14)
                radius: Math.round(width * 0.24)
                color: Theme.alpha(Theme.fg, button.isActive ? 0.3 : 0.2)
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.4)
            }

            PanelIcon {
                anchors.fill: parent
                implicitSize: button.taskbar.drawnIcon
                iconName: button.item.iconName
                iconFile: button.item.iconFile
            }
        }

        PanelText {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            visible: button.taskbar.titlesFit
            width: Math.min(title.implicitWidth, button.taskbar.titleRoom)
            elide: Text.ElideRight
            text: button.item.windows.length === 1
                ? WindowEvents.label(button.item.windows[0])
                : button.item.appName
        }
    }

    // Under the button, in the panel's margin: how many windows the
    // application has, and whether one of them is focused -- a long accent bar
    // for the focused one, a short mark per other window. Colour alone is the
    // distinction a person with low vision may not see at all, so the count is
    // shape as well as tint.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height + Math.max(1, Math.round((button.taskbar.barThickness - button.taskbar.buttonHeight) / 2 - 7))
        spacing: 3

        Repeater {
            // Past four the marks stop being countable and start being noise.
            model: Math.min(4, button.windowCount)

            Rectangle {
                required property int index

                width: button.isActive && index === 0 ? Math.round(22 * Math.max(0.7, button.taskbar.unit))
                                                     : Math.round(6 * Math.max(0.7, button.taskbar.unit))
                height: 3
                radius: 1.5
                color: button.isActive && index === 0 ? Theme.acc : Theme.alpha(Theme.fg, 0.4)
            }
        }
    }
}
