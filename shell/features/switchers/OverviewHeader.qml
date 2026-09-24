pragma ComponentBehavior: Bound

// The overview's header: what this is, how many desktops there are and which
// is in front, and what the keys do -- held or left up, whichever the
// overview was asked to be.

import QtQuick
import qs.domain.theme
import qs.domain.desktops
import qs.ui.primitives

Rectangle {
    id: header

    // The overview's, handed down: every desktop, what the keys do, and
    // whether the key is held.
    required property var desks
    required property var hints
    required property bool hold

    height: 56
    radius: Theme.radiusOf(20)
    color: Theme.glass
    border.width: 1
    border.color: Theme.out

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: "grid_view"
            fallback: "preferences-desktop-virtual"
            size: 24
            color: Theme.acc
        }

        PanelText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Desktops"
            font.pixelSize: 19
            font.weight: Font.Medium
            color: Theme.fg
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            width: deskCount.implicitWidth + 24
            radius: 13
            color: Theme.accC

            PanelText {
                id: deskCount
                anchors.centerIn: parent
                text: `${header.desks.length} desktop${header.desks.length === 1 ? "" : "s"} · in front ${
                    (header.desks.findIndex(d => d && d.id === Desktops.currentId) + 1) || 1}`
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.acc
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Repeater {
            model: header.hints

            Row {
                id: hint
                required property var modelData
                spacing: 6

                KeyCap {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hint.modelData.kbd
                }

                PanelText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hint.modelData.meaning
                    font.pixelSize: 12
                    color: Theme.mut
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            width: heldRow.implicitWidth + 26
            radius: 13
            color: Theme.s2
            border.width: 1
            border.color: Theme.out

            Row {
                id: heldRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 4
                    color: Theme.acc
                }
                PanelText {
                    text: header.hold ? "Meta held" : "Open until you choose"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.fg
                }
            }
        }
    }
}
