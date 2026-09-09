// One position in a zone: the widget, plus the interaction it asked for.
//
// The panel reads capabilities and calls the matching function. It never asks
// what a widget *is*. That is the difference between a panel that can host
// widgets it has never heard of and one that needs editing for each new type.

import QtQuick
import qs.ui.primitives

Item {
    id: root

    required property var entry
    required property var bar
    required property string screenName
    required property var widgetConfig

    readonly property BarWidget widget: host.item as BarWidget
    readonly property bool wantsHover: root.widget?.wantsHover ?? false
    readonly property bool wantsWheel: root.widget?.wantsWheel ?? false
    readonly property bool interactive: root.wantsHover || root.wantsWheel || !!root.widget?.popout

    implicitWidth: host.implicitWidth
    implicitHeight: host.implicitHeight

    WidgetHost {
        id: host
        anchors.fill: parent
        entry: root.entry
        bar: root.bar
        screenName: root.screenName
        widgetConfig: root.widgetConfig
    }

    MouseArea {
        anchors.fill: parent

        // A widget that asked for nothing stays click-through, so a decorative
        // widget cannot accidentally swallow input meant for the panel.
        enabled: root.interactive
        visible: root.interactive
        hoverEnabled: root.wantsHover
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPositionChanged: event => {
            if (root.wantsHover)
                root.widget.handleHover(root.bar.horizontal ? event.x : event.y, root.bar.horizontal);
        }

        onExited: if (root.wantsHover) root.widget.dismissPopout()

        onWheel: event => {
            if (!root.wantsWheel) {
                event.accepted = false;
                return;
            }
            // Normalise to steps: touchpads report pixel deltas, wheels report
            // 120ths of a degree. Widgets should not have to know which.
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y / 120
                                                   : event.pixelDelta.y / 50;
            root.widget.handleWheel(delta);
        }

        onClicked: event => root.widget?.handleActivate(event.button)
    }
}
