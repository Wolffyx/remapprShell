/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Alt+Tab.

    KWin draws this; only its appearance is ours. `TabBoxSwitcher` is the
    interface KWin drives -- it sets `model` and `currentIndex` and reads back
    `currentIndex` when the switcher chooses -- so those names are exactly as
    KWin expects and everything else is presentation.

    A row of icons rather than a list of lines: switching windows is a glance
    at what is open, and an icon is recognised faster than a title is read. The
    title of the highlighted window is shown once, underneath, rather than once
    per row.

    Colours come from the active colour scheme through Kirigami.Theme, which is
    the whole point of shipping one: this matches the panel without either
    knowing about the other.
*/

// The base type lives in KWin's own qrc and cannot be resolved by the linter,
// so its properties would otherwise all read as unqualified access.
// qmllint disable unqualified
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox

    currentIndex: iconRow.currentIndex

    readonly property int iconSize: Kirigami.Units.iconSizes.huge
    readonly property int cellPadding: Kirigami.Units.largeSpacing

    PlasmaCore.Dialog {
        id: dialog

        location: PlasmaCore.Types.Floating
        visible: tabBox.visible
        flags: Qt.Popup | Qt.X11BypassWindowManagerHint

        x: tabBox.screenGeometry.x + (tabBox.screenGeometry.width - dialog.width) / 2
        y: tabBox.screenGeometry.y + (tabBox.screenGeometry.height - dialog.height) / 2

        mainItem: Item {
            id: content

            // Wide enough for the icons, but never wider than most of the
            // screen: with thirty windows open the row scrolls rather than
            // running off both edges.
            readonly property int maxWidth: tabBox.screenGeometry.width * 0.8

            implicitWidth: Math.min(content.maxWidth, iconRow.implicitContentWidth + 2 * tabBox.cellPadding)
            implicitHeight: iconRow.height + caption.height + 3 * tabBox.cellPadding

            ListView {
                id: iconRow

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: tabBox.cellPadding
                anchors.leftMargin: tabBox.cellPadding
                anchors.rightMargin: tabBox.cellPadding

                height: tabBox.iconSize + 2 * Kirigami.Units.smallSpacing
                orientation: ListView.Horizontal
                clip: true
                focus: true
                boundsBehavior: Flickable.StopAtBounds
                // Keeps the highlighted window in view when there are more of
                // them than fit.
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: width / 2 - cellWidth
                preferredHighlightEnd: width / 2 + cellWidth
                highlightMoveDuration: Kirigami.Units.shortDuration

                readonly property int cellWidth: tabBox.iconSize + 2 * Kirigami.Units.smallSpacing

                model: tabBox.model

                delegate: Item {
                    id: entry

                    required property int index
                    required property string caption
                    required property var icon
                    required property bool minimized

                    width: iconRow.cellWidth
                    height: iconRow.height

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.highlightColor
                        opacity: entry.index === iconRow.currentIndex ? 0.35 : 0
                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: tabBox.iconSize
                        height: tabBox.iconSize
                        source: entry.icon
                        // A minimised window is still a window; it is dimmed
                        // rather than hidden, so Alt+Tab can reach it.
                        opacity: entry.minimized ? 0.5 : 1
                    }

                    TapHandler {
                        onTapped: {
                            iconRow.currentIndex = entry.index;
                            tabBox.model.activate(entry.index);
                        }
                    }
                }

                Connections {
                    target: tabBox
                    function onCurrentIndexChanged(): void {
                        iconRow.currentIndex = tabBox.currentIndex;
                    }
                }
            }

            PlasmaComponents3.Label {
                id: caption

                anchors.top: iconRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: tabBox.cellPadding
                anchors.leftMargin: tabBox.cellPadding
                anchors.rightMargin: tabBox.cellPadding

                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                text: iconRow.currentItem?.caption ?? ""
            }

            PlasmaComponents3.Label {
                anchors.centerIn: parent
                visible: iconRow.count === 0
                textFormat: Text.PlainText
                opacity: 0.7
                text: "No open windows"
            }

            // Key handling belongs on the outer item: on the list view it is
            // lost between invocations, which shows up as Alt+Tab working the
            // first time and not the second.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    iconRow.decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    iconRow.incrementCurrentIndex();
                    event.accepted = true;
                }
            }
        }
    }
}
