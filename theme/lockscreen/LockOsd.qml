/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Volume, brightness and the like, while the screen is locked.

    The greeter finds this by its object name, sets the properties below and
    calls show(). The names are that interface, which is why they are
    Plasma's; the drawing matches the shell's own OSD.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: osd

    // --- the interface the greeter drives -------------------------------

    property int timeout: 1800
    property var osdValue: 0
    property int osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon: ""
    property bool showingProgress: false

    function show() {
        fade.stop();
        osd.opacity = 1;
        osd.visible = true;
        hideTimer.restart();
    }

    // --- presentation ----------------------------------------------------

    readonly property real progress: osd.osdMaxValue > 0
        ? Math.max(0, Math.min(1, Number(osd.osdValue) / osd.osdMaxValue))
        : 0

    objectName: "onScreenDisplay"
    visible: false
    radius: Kirigami.Units.gridUnit
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                   Kirigami.Theme.backgroundColor.b, 0.85)
    implicitWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: row.implicitHeight + Kirigami.Units.largeSpacing * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: osd.icon
            visible: osd.icon.length > 0
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }

        Item {
            visible: osd.showingProgress
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.preferredHeight: Kirigami.Units.gridUnit / 2

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Kirigami.Theme.textColor
                opacity: 0.15
            }

            Rectangle {
                width: parent.width * osd.progress
                height: parent.height
                radius: height / 2
                color: Kirigami.Theme.highlightColor
                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        Kirigami.Heading {
            level: 4
            text: osd.showingProgress
                ? `${Math.round(osd.progress * 100)}%`
                : (osd.osdValue !== undefined ? String(osd.osdValue) : "")
            color: Kirigami.Theme.textColor
            Layout.minimumWidth: osd.showingProgress ? Kirigami.Units.gridUnit * 2 : 0
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
            elide: Text.ElideRight
            horizontalAlignment: osd.showingProgress ? Text.AlignRight : Text.AlignLeft
        }

        Kirigami.Heading {
            visible: osd.osdAdditionalText.length > 0
            level: 5
            opacity: 0.7
            text: osd.osdAdditionalText
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 10
        }
    }

    Timer {
        id: hideTimer
        interval: osd.timeout
        onTriggered: fade.start()
    }

    SequentialAnimation {
        id: fade
        NumberAnimation { target: osd; property: "opacity"; to: 0; duration: Kirigami.Units.shortDuration }
        ScriptAction {
            script: {
                osd.visible = false;
                osd.opacity = 1;
                osd.icon = "";
                osd.osdValue = 0;
            }
        }
    }
}
