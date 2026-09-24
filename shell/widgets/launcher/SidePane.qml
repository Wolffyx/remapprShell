pragma ComponentBehavior: Bound

// The two-pane start menu's side: who is signed in, what is playing, the
// machine, and the session's buttons at the foot.

import QtQuick
import qs.domain.launcher.providers
import qs.domain.session
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Item {
    id: side

    required property BuiltinProvider provider

    Rectangle {
        width: 1
        height: parent.height
        color: Theme.out
    }

    Column {
        x: 20
        y: 22
        width: parent.width - 40
        spacing: 14

        Item {
            width: parent.width
            height: 44

            Avatar {
                id: sideAvatar
                size: 44
                source: Session.avatar
                initial: Session.initial
            }

            Column {
                anchors.left: sideAvatar.right
                anchors.leftMargin: 12
                anchors.right: sidePower.left
                anchors.verticalCenter: parent.verticalCenter

                PanelText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Session.displayName
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                PanelText {
                    text: Session.uptime
                    font.family: Theme.monoFamily
                    font.pixelSize: 12
                    color: Theme.mut
                }
            }

            IconButton {
                id: sidePower
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: 36
                glyph: "power_settings_new"
                iconName: "system-shutdown"
                onActivated: {
                    Session.prompt("promptAll");
                    side.provider.close();
                }
            }
        }

        NowPlaying { width: parent.width }

        MachineMeters { width: parent.width }
    }

    Row {
        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        spacing: 8

        Repeater {
            model: [
                { glyph: "lock", act: () => Session.lock() },
                { glyph: "bedtime", act: () => Session.suspend() },
                { glyph: "logout", act: () => Session.prompt("promptLogout") }
            ]

            Rectangle {
                id: sessionButton
                required property var modelData
                width: (side.width - 40 - 16) / 3
                height: 44
                radius: Theme.radiusOf(14)
                color: sessionHover.hovered ? Theme.s3 : Theme.s1

                Glyph {
                    anchors.centerIn: parent
                    name: sessionButton.modelData.glyph
                    size: 20
                }

                HoverHandler { id: sessionHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        side.provider.close();
                        sessionButton.modelData.act();
                    }
                }
            }
        }
    }
}
