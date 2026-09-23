// The taskbar's hover preview, at the window counts that change its shape.
//
// Rendered offscreen, so there are no screencast streams and every card falls
// back to the application's icon -- which is what this is for: the layout, the
// captions and the sizes, without a live picture to look at instead.

import QtQuick
import qs.domain.theme
import qs.widgets.tasks

Rectangle {
    id: stage

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.dark ? "#20283f" : "#c8d5ef" }
        GradientStop { position: 0.45; color: Theme.dark ? "#2c2b3d" : "#e6dcd2" }
        GradientStop { position: 1; color: Theme.dark ? "#3b3138" : "#f2d7c4" }
    }

    function win(title, opts) {
        return Object.assign({
            uuid: title, title: title, appId: "preview", desktopFile: "",
            minimized: false, active: false, attention: false,
            output: "DP-2", stacking: 1, iconPath: "",
            desktops: [], width: 1920, height: 1080
        }, opts || {});
    }

    readonly property var scenes: [
        {
            label: "one window",
            item: { appName: "Claude", iconName: "claude", iconFile: "", windows: [] },
            windows: [stage.win("Claude")]
        },
        {
            label: "two windows",
            item: { appName: "Google Chrome", iconName: "google-chrome", iconFile: "", windows: [] },
            windows: [
                stage.win("The Steam Frame Shouldn't Work — YouTube", { active: true }),
                stage.win("Google Meet")
            ]
        },
        {
            label: "a tall window",
            item: { appName: "Spectacle", iconName: "spectacle", iconFile: "", windows: [] },
            windows: [stage.win("Unsaved* — Spectacle", { width: 900, height: 1300 })]
        },
        {
            label: "four, one minimised, header on",
            header: true,
            item: { appName: "Spectacle", iconName: "spectacle", iconFile: "", windows: [] },
            windows: [
                stage.win("Unsaved — Spectacle", { active: true }),
                stage.win("Unsaved — Spectacle"),
                stage.win("Unsaved — Spectacle", { minimized: true }),
                stage.win("Unsaved — Spectacle")
            ]
        }
    ]

    Flow {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 28

        Repeater {
            model: stage.scenes

            Column {
                id: scene
                required property var modelData
                spacing: 10

                Text {
                    text: scene.modelData.label
                    color: Theme.dark ? "#ffffff" : "#1a1b21"
                    opacity: 0.75
                    font.pixelSize: 12
                }

                Rectangle {
                    width: card.width
                    height: card.height
                    radius: Theme.radiusOf(18)
                    color: Theme.surfaceContainer

                    TaskPreview {
                        id: card
                        width: implicitWidth
                        height: implicitHeight
                        item: scene.modelData.item
                        windows: scene.modelData.windows
                        showHeader: scene.modelData.header === true
                    }
                }
            }
        }
    }
}
