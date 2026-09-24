pragma ComponentBehavior: Bound

// Taskbar: the displays card -- one block per monitor, each able to keep a
// position, style, hiding and size of its own, and to give them back.
//
// A card of the taskbar page, apart from it because it is a page of its own
// in miniature: a block per screen, built from the screens there are. The
// choices it offers are the page's, handed in, so the shared rows and the
// per-monitor rows can never offer different ones.

import QtQuick
import Quickshell
import qs.domain.config
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    // The page's choices for the panel's position and style.
    required property var positionValues
    required property var positionLabels
    required property var styleValues
    required property var styleLabels

    SectionLabel { text: "Displays" }

    Hint {
        text: Quickshell.screens.length > 1
            ? "Each monitor draws its own panel. Where it sits, how it is drawn, whether it hides and its size can differ per monitor; the widgets are shared."
            : "One monitor. With a second one connected, each draws its own panel and can keep its own position, style, hiding and size."
    }

    Repeater {
        model: Quickshell.screens

        Column {
            id: screenBlock

            required property var modelData

            readonly property string name: screenBlock.modelData.name
            // Every key the panel reads per screen (PanelModel.*For) that
            // this block offers. Setting one back to the shared value
            // drops the override rather than freezing a copy of it.
            readonly property var ownKeys: ["panel.position", "panel.thickness", "panel.style",
                                             "panel.autoHide", "panel.iconSize"]
            readonly property bool overridden: screenBlock.ownKeys.some(
                k => ConfigStore.isOverriddenForScreen(screenBlock.name, k))

            function useShared() {
                for (const k of screenBlock.ownKeys)
                    ConfigStore.setForScreen(screenBlock.name, k, ConfigStore.value(k, undefined));
            }

            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: 24

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${screenBlock.name} · ${screenBlock.modelData.width}×${screenBlock.modelData.height}`
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                PanelText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: screenBlock.overridden
                    text: "its own"
                    font.pixelSize: 12
                    color: Theme.acc
                }
            }

            ConfigSegmented {
                width: parent.width
                values: root.positionValues
                labels: root.positionLabels
                screen: screenBlock.name
                path: "panel.position"
            }

            ConfigSliderRow {
                label: "Thickness on this monitor"
                from: 28
                to: 96
                stepSize: 2
                screen: screenBlock.name
                path: "panel.thickness"
            }

            ConfigSegmented {
                width: parent.width
                values: root.styleValues
                labels: root.styleLabels
                screen: screenBlock.name
                path: "panel.style"
            }

            ConfigSliderRow {
                label: "Tray icon size on this monitor"
                from: 15
                to: 26
                screen: screenBlock.name
                path: "panel.iconSize"
            }

            ConfigToggleRow {
                width: parent.width
                label: "Hide until pointed at, on this monitor"
                screen: screenBlock.name
                path: "panel.autoHide"
            }

            TextButton {
                visible: screenBlock.overridden
                glyph: "sync"
                iconName: "edit-undo"
                text: "Use the shared settings"
                onActivated: screenBlock.useShared()
            }
        }
    }
}
