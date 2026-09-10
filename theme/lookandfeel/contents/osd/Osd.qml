/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The on-screen display for volume, brightness and similar.

    Plasma draws this; only its appearance is ours. The window type and the six
    properties below are the interface plasmashell drives, so they are named
    and aliased exactly as it expects -- everything else is presentation.
*/

// The base type comes from plasmashell's own qrc, which the linter cannot
// resolve, so every property it provides reads as unqualified access. The
// directive keeps that noise out of the way of real findings.
// qmllint disable unqualified
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.osd

OsdWindow {
    id: root

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property alias timeout: osd.timeout
    property alias osdValue: osd.osdValue
    property alias osdMaxValue: osd.osdMaxValue
    property alias osdAdditionalText: osd.osdAdditionalText
    property alias icon: osd.icon
    property alias showingProgress: osd.showingProgress

    // Narrower than Plasma's default, which spans half the screen even to show
    // a single number. A volume change is a glance, not a dialogue.
    width: mainItem.implicitWidth + leftPadding + rightPadding
    height: mainItem.implicitHeight + topPadding + bottomPadding

    mainItem: OsdItem {
        id: osd
    }
}
