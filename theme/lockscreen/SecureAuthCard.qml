/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The secure style's way in: a card with the method tabs, when there is
    anything besides the password to choose, over the password panel and
    the key panel.

    Which of the two is up is decided here. The key comes first, as the
    design has it, whenever the greeter says there is one; typing, the
    password tab, or "Use password instead" choose the password; and the
    prompt going away with nothing typed puts the key back first.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: card

    required property var ui
    required property SecurePalette colours
    property real unit: 1

    // For the line under the field: whether pam_faillock is known to count
    // this account's failures, and whether times are said in twelve hours.
    property bool faillock: false
    property bool twelveHour: false

    // The field, for the style to hand to the frame.
    readonly property LockPrompt field: passwordPanel.field

    function px(v: real): int {
        return Math.round(v * card.unit);
    }

    // --- what the greeter says it has --------------------------------------

    readonly property bool hasFingerprint: card.ui.unlock.hasFingerprint
    readonly property bool hasSmartcard: card.ui.unlock.hasSmartcard
    readonly property bool hasAlternative: card.hasFingerprint || card.hasSmartcard

    // "key" or "password", as the tabs choose. The key comes first, as the
    // design has it, whenever there is one.
    property string chosen: "key"
    readonly property bool keyMode: card.hasAlternative && card.chosen === "key"
        && !card.ui.unlock.unlockedWithoutPassword

    readonly property string keyTitle: card.hasSmartcard && card.hasFingerprint ? "Key or fingerprint"
        : card.hasSmartcard ? "Security key" : "Fingerprint"
    readonly property string keyGlyph: card.hasSmartcard ? "usb" : "fingerprint"
    readonly property string keyAsk: card.hasSmartcard && card.hasFingerprint
        ? "Use your security key, or touch the fingerprint sensor"
        : card.hasSmartcard ? "Insert or touch your security key" : "Touch the fingerprint sensor"

    Connections {
        target: card.ui.unlock

        function onShownChanged() {
            if (!card.ui.unlock.shown && passwordPanel.field.text.length === 0)
                card.chosen = "key";
        }
    }

    height: cardBody.height + card.px(68)
    radius: card.px(24)
    color: card.colours.card
    border.width: 1
    border.color: card.colours.cardLine

    Column {
        id: cardBody

        x: card.px(40)
        y: card.px(32)
        width: parent.width - 2 * x
        spacing: card.px(34)

        // Only when there is something besides the password to choose.
        Rectangle {
            visible: card.hasAlternative && !card.ui.unlock.unlockedWithoutPassword
            width: tabs.implicitWidth + card.px(10)
            height: tabs.implicitHeight + card.px(10)
            radius: card.px(14)
            color: card.colours.ground

            Row {
                id: tabs
                anchors.centerIn: parent
                spacing: card.px(6)

                SecureTab {
                    colours: card.colours
                    unit: card.unit
                    glyph: card.hasSmartcard ? "key" : "fingerprint"
                    label: card.keyTitle
                    active: card.keyMode
                    onChosen: {
                        card.chosen = "key";
                        card.ui.focusPassword();
                    }
                }

                SecureTab {
                    colours: card.colours
                    unit: card.unit
                    glyph: "password"
                    label: "Password"
                    active: !card.keyMode
                    onChosen: {
                        card.chosen = "password";
                        card.ui.focusPassword();
                    }
                }
            }
        }

        // The key panel sits over the password one rather than replacing
        // it, so the field keeps the keyboard: the first key typed is the
        // first character of the password, and switches to it.
        Item {
            width: parent.width
            height: card.keyMode ? keyPanel.height : passwordPanel.height

            SecurePasswordPanel {
                id: passwordPanel

                width: parent.width
                opacity: card.keyMode ? 0 : 1
                ui: card.ui
                colours: card.colours
                unit: card.unit
                faillock: card.faillock
                twelveHour: card.twelveHour
                onTyped: card.chosen = "password"
            }

            SecureKeyPanel {
                id: keyPanel

                visible: card.keyMode
                width: parent.width
                ui: card.ui
                colours: card.colours
                unit: card.unit
                glyph: card.keyGlyph
                ask: card.keyAsk
                onPasswordChosen: {
                    card.chosen = "password";
                    card.ui.focusPassword();
                }
            }
        }
    }
}
