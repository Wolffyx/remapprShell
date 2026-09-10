/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Contents of the on-screen display.

    The property block is the interface plasmashell sets; the layout is ours.
    Colours come from Kirigami.Theme, which resolves to the active Plasma
    colour scheme, so this follows the desktop rather than defining a palette
    of its own.
*/

// The base type comes from plasmashell's own qrc, which the linter cannot
// resolve, so every property it provides reads as unqualified access. The
// directive keeps that noise out of the way of real findings.
// qmllint disable unqualified
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    // --- the interface plasmashell drives -------------------------------

    property int timeout: 1800
    property var osdValue                 // a number when showingProgress, else text
    property int osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon
    property bool showingProgress: false

    // --- presentation ----------------------------------------------------

    readonly property int barLength: Kirigami.Units.gridUnit * 12
    readonly property real progress: root.osdMaxValue > 0
        ? Math.max(0, Math.min(1, Number(root.osdValue) / root.osdMaxValue))
        : 0

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        source: root.icon
        visible: valid && root.icon.length > 0
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        Layout.alignment: Qt.AlignVCenter
    }

    // Progress form: a single slim bar. A percentage figure is rarely what the
    // user wants to know -- how full it is, is.
    Item {
        visible: root.showingProgress
        Layout.preferredWidth: root.barLength
        Layout.preferredHeight: Kirigami.Units.gridUnit / 2
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: 0.15
        }

        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: height / 2
            color: Kirigami.Theme.highlightColor

            // Follows the value rather than jumping, so a held volume key reads
            // as one movement instead of a flicker.
            Behavior on width {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    Kirigami.Heading {
        visible: root.showingProgress
        level: 4
        text: `${Math.round(root.progress * 100)}%`
        color: Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignRight
        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
        Layout.alignment: Qt.AlignVCenter
    }

    // Text form: for things with no scale, such as a keyboard layout or
    // "touchpad disabled".
    Kirigami.Heading {
        visible: !root.showingProgress
        level: 4
        text: root.osdValue !== undefined ? String(root.osdValue) : ""
        color: Kirigami.Theme.textColor
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 16
        Layout.alignment: Qt.AlignVCenter
    }

    Kirigami.Heading {
        visible: root.osdAdditionalText.length > 0
        level: 5
        opacity: 0.7
        text: root.osdAdditionalText
        color: Kirigami.Theme.textColor
        elide: Text.ElideRight
        Layout.maximumWidth: Kirigami.Units.gridUnit * 10
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.alignment: Qt.AlignVCenter
    }
}
